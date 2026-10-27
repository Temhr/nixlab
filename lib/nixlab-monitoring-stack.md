# Nixlab Monitoring Stack — Architecture & Reference

> **State of this document:** reflects the repo **after Stage 8** of
> `nixlab-monitoring-fix-guide.md` (Stages 1–8 applied). Stages 9–14 are
> pending and are called out as *(pending, Stage N)* wherever they would
> change what's written here. §13 holds the changelog and the open items.

Derived from every file in the monitoring stack: the aggregator
(`stacks/monitoring.nix`), the five service modules (loki + alloy,
prometheus, alertmanager, grafana, ntfy), the two `nsops--*` secrets joiners
(grafana, alertmanager), the Grafana dashboards, the Prometheus alert/recording
rules, and the `maintenance-log` helper script. It is written so you (or
Claude) can reason about, debug, or extend the stack **without needing the
code base** — paste this file into a prompt and Claude has the whole picture.

This file is the companion to `nixlab-module-template.md`. That file explains
*how every module is written* (naming, options order, `nixlabLib` helpers,
the `servc--` / `nsops--` / `systm--` split). This file explains *what the
monitoring modules actually do and how they connect*. Section references like
"template §8" point into that file.

**Sources.** Besides the monitoring modules themselves, this was
cross-checked against `modules/ports.nix`, the full `flake/nixos-lib.nix`
(`nixlabLib`, including `mkWalSelfHeal`, which template §8 doesn't cover), and
the repo `README.md` (flake architecture). Still not seen: host files
(`hosts/<name>.nix`), `hosts--profl--base` itself, and the encrypted
`grafana.yaml` / `alertmanager.yaml`. The few statements that depend on those
are marked *(not verified)*. Changes from Stages 1–8 were applied by the
owner; Stages 1–3 were verified from command output, Stages 4–8 are described
as designed in the guide *(outputs not reviewed)*.

---

## 0. One-paragraph summary

One flake module, `stack--monitoring`, turns on and cross-wires five services
on a single host: **Prometheus** (metrics + alert/recording rules),
**Alertmanager** (routing/dedup), **ntfy** (push notifications), **Loki** (log
store) with **Grafana Alloy** (log collector), and **Grafana** (dashboards,
datasources auto-provisioned). Alerts flow Prometheus → Alertmanager → ntfy
webhook, rendered through ntfy message templates, with `severity=critical`
routed to a separate max-priority receiver. Logs flow journald and
`/var/log/*.log` → Alloy → Loki. Grafana reads both Prometheus and Loki.
Prometheus scrapes every service in the stack (not just itself). A
"maintenance" layer (opt-in per service) adds exporters, alert rules mapped to
a 31-section server-maintenance checklist (34 base rules; 27 load by default,
the rest are enabled by feature flags), recording rules that feed dashboard
health scores, and a `maintenance-log` CLI that writes JSON task records into
Loki. The stack never owns port numbers: it reads each service's resolved port.

---

## 1. Component map

```
 ┌──────────────────────────────── one host ────────────────────────────────┐
 │                                                                          │
 │  node_exporter :9100 ─┐                                                  │
 │  systemd_exp   :9558 ─┤ scrape      rules/alerts     webhook (templated) │
 │  smartctl_exp  :9633 ─┼──────► Prometheus :9090 ──► Alertmanager :9093 ──┼─► ntfy :2586
 │  blackbox      :9115 ─┤            ▲                                     │      ▲
 │  optional integrations┘            │ scrapes (loopback): ntfy, loki,     │      │
 │   (traefik/cAdvisor/postgres)      │ grafana, alertmanager, alloy ───────┼──────┘ (/metrics)
 │                                                                          │
 │  Grafana :3101 ◄── datasources ──► Prometheus  +  Loki :3100             │
 │                                                  ▲                       │
 │  journald + /var/log/*.log ──► Alloy :12345 ─────┘                       │
 │  /var/log/maintenance.jsonl (opt-in) ──► Alloy ──► Loki                  │
 └──────────────────────────────────────────────────────────────────────────┘
```

| Service | Flake module attr | Option namespace | systemd unit | Default port | Runs as | Data dir (via stack) |
|---|---|---|---|---|---|---|
| Prometheus | `servc--prometheus-nixlab` | `services.prometheus-nixlab` | `prometheus` | 9090 | `prometheus` (hardcoded) | `/data/prometheus` |
| node exporter | (part of prometheus module) | `…prometheus-nixlab.enableNodeExporter` | `prometheus-node-exporter` (custom unit) | 9100 (localhost only, hardcoded) | `prometheus` | `/var/lib/node_exporter` (StateDirectory, only with maintenance) |
| Alertmanager | `servc--alertmanager-nixlab` | `services.alertmanager-nixlab` | `alertmanager` (upstream unit) | 9093 (cluster gossip 9094) | upstream `DynamicUser` | upstream `StateDirectory` |
| ntfy | `servc--ntfy-nixlab` | `services.ntfy-nixlab` | `ntfy` | 2586 | `ntfy` | `/data/ntfy` |
| Loki | `servc--loki-nixlab` | `services.loki-nixlab` | `loki` | 3100 (gRPC 9096; firewall opening pending change, Stage 9a) | `loki` | `/data/loki` |
| Alloy | (part of loki module) | `…loki-nixlab.enableAlloy` | `alloy` | `alloyPort` = 12345 (loopback; UI + `/metrics`; default set in `ports.nix`) | `alloy` | `/var/lib/alloy` (fixed) |
| Grafana | `servc--grafana-nixlab` | `services.grafana-nixlab` | `grafana` | 3101 | `grafana` | `/data/grafana` |
| Stack aggregator | `stack--monitoring` | `services.nixlab-monitoring` | — | — | — | `/data` root |
| Secrets joiners | `nsops--grafana`, `nsops--alertmanager` | add `.secretsFile` to the service namespace | — | — | — | — |

Optional exporters, only present when `prometheus-nixlab.maintenance.enable`:
systemd exporter `:9558`, smartctl exporter `:9633`, blackbox exporter
`:9115` (HTTP, ICMP, SSL and, with `dnsTargets`, DNS probes), and a custom
backup-status exporter (off by default, writes a textfile for node_exporter).
Hosts may additionally switch on `integrations.{traefik,cadvisor,postgres}` in
the stack (§3.1) to scrape those exporters and enable their alert rules.

`nixlab.mainUser` (and `extraUsers`) are added as members of every service's
group (`loki`+`alloy`, `grafana`, `prometheus`, `alertmanager`, `ntfy`) so the
admin user can read data directories.

---

## 2. File layout

```
/nixlab/stacks/monitoring.nix                                   # stack--monitoring aggregator (§3)

/nixlab/modules/nixos/monitoring/
├── loki/
│   ├── default.nix                    # Loki + Alloy + maintenance-log wrapper (§5)
│   └── maintenance-logger.sh          # `maintenance-log` CLI, embedded via builtins.readFile (§5.4)
├── prometheus/
│   ├── default.nix                    # thin entry: options + mkIf cfg.enable config (§4)
│   └── _internals/                    # underscore = private, not flake modules
│       ├── options.nix                # ALL option declarations (incl. maintenance.*)
│       ├── config.nix                 # assembles users/dirs/services/exporters/nginx/firewall
│       ├── scrape-configs.nix         # scrape job builders (+ mkBlackboxJob; DNS job)
│       ├── alerts.nix                 # `{ groups = []; }` — placeholder for non-maintenance alerts
│       ├── maintenance-alerts.nix     # ALL real alert + recording rules; function of `{features}` (§7, §8)
│       ├── services/prometheus.nix    # the systemd.services.prometheus body + preStart
│       ├── exporters/node.nix         # custom prometheus-node-exporter unit
│       ├── exporters/maintenance.nix  # systemd / blackbox / smartctl / backup exporters
│       └── extras/nginx.nix           # nginx vhost for Prometheus
├── alertmanager/default.nix           # wrapper around upstream services.prometheus.alertmanager (§6)
├── grafana/
│   ├── default.nix                    # Grafana unit + dashboard/datasource provisioning (§9)
│   └── dashboards/
│       ├── maintenance-checklist.json # base dashboard "maintenance"
│       ├── system-overview-v5.json    # base dashboard "system-overview-v5"
│       └── zfs-monitoring.json        # opt-in via extraDashboards
└── ntfy/default.nix                   # ntfy server (§10)

/nixlab/sops/grafana.nix        + grafana.yaml        # nsops--grafana (§11)
/nixlab/sops/alertmanager.nix   + alertmanager.yaml   # nsops--alertmanager (§11)

/nixlab/bin/monitoring-smoke.sh                                 # health/targets/rules/alerts/Loki-labels smoke test (not a module)
```

Absolute root on disk: `/home/temhr/nixlab/`. Only Prometheus uses the
multi-file `_internals/` pattern (template §1).

### 2.1 How it plugs into the flake

- **Registration.** `flake.nix` is pure delegation; `import-tree` discovers every
  `.nix` file under `./modules`, `./stacks`, `./sops` and `./flake`, and each
  file registers itself into `flake.nixosModules.<name>`. Names in play:
  `servc--{loki,prometheus,alertmanager,grafana,ntfy}-nixlab`,
  `systm--ports-{loki,grafana,prometheus,alertmanager,ntfy}`,
  `nsops--{grafana,alertmanager}`, `stack--monitoring`. Everything references
  everything else by `self.nixosModules.<name>`, never by path.
- **Layer rules** (README): `servc--` modules are atomic and know nothing about
  sibling services; all cross-service knowledge lives in `stacks/`; a stack
  implements no service logic (no systemd units, no users) and only sets options
  the underlying modules already expose; secrets wiring lives only in `sops/`.
- **`nixlabLib`** is `flake.lib.nixlabLib`, injected into every NixOS module's
  `specialArgs` by `mkHost` (alongside `allHosts`, `hostMeta`, `self`, `inputs`).
- **Enablement.** Per the README, `hosts--profl--base` (every host) composes
  `stack--monitoring`, so the module is available everywhere and
  `services.nixlab-monitoring.enable` is the per-host switch *(host files not
  verified)*. Scrape targets are all `localhost`, so each host that enables the
  stack monitors **only itself**; there is no cross-host aggregation.
- **`nixlab.mainUser`** is derived (`lib.mkDefault hostsMeta.<host>.primaryUser`);
  it feeds the group-membership blocks in every module.
- **Flakes only see git-tracked files** — `git add -A` after adding a dashboard
  JSON, rule file or module, before `nix flake check` / rebuild.

---

## 3. The stack aggregator — `stack--monitoring`

`/nixlab/stacks/monitoring.nix`. Enabled with
`services.nixlab-monitoring.enable = true`. Imports `nsops--alertmanager`,
`nsops--grafana` (each of which imports its own `servc--*`), plus
`servc--loki-nixlab`, `servc--prometheus-nixlab`, `servc--ntfy-nixlab`.

### 3.1 Options

| Option | Default | Purpose |
|---|---|---|
| `enable` | — | Turn on the whole stack |
| `listenAddress` | `"0.0.0.0"` | Bind address for **all** services *(split into user-facing vs backend addresses, pending Stage 9c)* |
| `openFirewall` | `true` | Passed to all services |
| `dataDir` | `"/data"` | Root; each service gets `<dataDir>/<name>` |
| `loki.retention` | `"744h"` (31 d) | |
| `loki.maintenance.enable` | false | Enables `maintenance-log` CLI + maintenance log ingestion |
| `prometheus.maintenance.enable` | false | **Enables all alert rules, recording rules and extra exporters** |
| `prometheus.maintenance.exporters.systemd` | true | standalone systemd exporter *(default flips to false, pending Stage 11c)* |
| `prometheus.maintenance.exporters.smartctl.enable` | true | |
| `ntfy.cachePersist` | true | Sets `cacheFile = <dataDir>/ntfy/cache.db` |
| `notifications.useNtfy` | true | Wire Alertmanager default receiver to local ntfy |
| `notifications.ntfyTopic` | `"alerts"` | Topic Alertmanager publishes to |
| `notifications.formatMessages` | true | Use ntfy templating (`tpl=1&t=…&m=…`) so messages show alert summary/description instead of raw JSON (needs ntfy ≥ 2.10) |
| `notifications.separateCritical` | true | Route `severity=critical` to receiver `ntfy-critical` (priority 5, tag `rotating_light`) |
| `integrations.traefik.{enable,target}` | false / `127.0.0.1:8082` | Scrape traefik **and** enable `HighHTTPErrorRate` |
| `integrations.cadvisor.{enable,target}` | false / `127.0.0.1:8080` | Scrape cAdvisor **and** enable `ContainerRestartLoop`/`ContainerHighMemory` |
| `integrations.postgres.{enable,target}` | false / `127.0.0.1:9187` | Scrape postgres exporter **and** enable `PostgresReplicationLag` |

**Removed in Stages 4–5:** `ports.{grafana,loki,prometheus,alertmanager,ntfy}`
and `loki.grpcPort`. Ports are now set only in `modules/ports.nix` (`mkDefault`)
or by a plain assignment on the service in a host file.

### 3.2 What it wires (the "synergy" layer)

Neither Prometheus, Alertmanager, Grafana nor Loki know about each other.
All cross-service knowledge lives in this file.

**Port resolution.** The stack reads each service's *resolved*
`config.services.<x>.port` (`port.grafana`, `port.loki`, …) for every URL and
target it builds, so a host-level port override flows through everything.

1. **Per-service basics** — `listenAddress`, `dataDir = "${dataDir}/<svc>"`,
   `openFirewall`, plus Loki `retention`/`maintenance.enable` and Prometheus
   `maintenance.{enable,exporters.systemd,exporters.smartctl.enable}`. **All of
   these are `lib.mkDefault`** (override via the stack option *or* directly on
   the service). No service gets a `domain`, so **no nginx vhosts by default**.
2. **Grafana datasources** (`grafana-nixlab.provisioning.datasources`):
   `Prometheus` → `http://127.0.0.1:<prom port>` (`isDefault = true`) and
   `Loki` → `http://127.0.0.1:<loki port>`. *(Stable `uid`s pending, Stage 12a.)*
3. **Prometheus scrapes the stack** (`prometheus-nixlab.extraScrapeConfigs`),
   all via loopback: jobs `ntfy`, `loki`, `grafana`, `alertmanager`, and `alloy`
   (when `enableAlloy`, port `loki-nixlab.alloyPort`). Plus `traefik`,
   `cadvisor`, `postgres` when the matching `integrations.*.enable` is set.
4. **Alert feature flags** (`prometheus-nixlab.maintenance.alerts.features`):
   `traefik`, `containers`, `postgres` mirror the `integrations.*.enable`
   values (`lib.mkDefault`). One option therefore connects "this exporter is
   scraped" to "its alert rule is loaded".
5. **Prometheus → Alertmanager**: `alertmanagerTargets = ["127.0.0.1:<am port>"]`.
6. **Alertmanager → ntfy**: when `useNtfy`, `defaultReceiver = "ntfy"`.
   Receivers: `null`, `ntfy` (`tags=warning`) and, with `separateCritical`,
   `ntfy-critical` (`p=5&tags=rotating_light`). With `formatMessages` each URL
   carries `tpl=1`, a title template `[{{.status}}] {{(index .alerts 0).labels.alertname}}`
   and a message template ranging over `.alerts` (`summary` + `description`),
   URL-escaped with `lib.escapeURL`. A child route sends
   `severity="critical"` to `ntfy-critical` (`groupWait=10s`,
   `repeatInterval=1h`). Loopback is used regardless of ntfy's bind address.
   With `useNtfy = false` the default receiver is `"null"` (drop): define your
   own receivers on the host.
7. **ntfy** gets `cacheFile` when `cachePersist` (`mkDefault`).

The stack only touches options each module deliberately exposes as an
injection point: `grafana-nixlab.provisioning.datasources`,
`prometheus-nixlab.{extraScrapeConfigs,alertmanagerTargets,maintenance.alerts.features}`,
`alertmanager-nixlab.{receivers,defaultReceiver,route.routes}`,
`ntfy-nixlab.cacheFile`. To integrate something new, extend one of these from
the stack (or a host) rather than editing a `servc--` module.

### 3.3 Override contract

- **Tunables** (`listenAddress`, `dataDir`, `openFirewall`, `retention`,
  `maintenance.*`, `cacheFile`, feature flags) are `mkDefault`: set them via the
  stack option **or** directly on `services.<x>-nixlab.*` in a host file; no
  eval conflict either way.
- **Wiring** (datasources, scrape jobs, receivers, route, `alertmanagerTargets`)
  is plain and additive: extend it, don't replace it.
- **Ports** are never set by the stack. Precedence: host plain assignment >
  `ports.nix` `mkDefault` > module default.

### 3.4 Typical host config

```nix
imports = [ self.nixosModules.stack--monitoring ];

services.nixlab-monitoring = {
  enable = true;
  loki.maintenance.enable = true;        # maintenance-log CLI + log ingestion
  prometheus.maintenance.enable = true;  # without this: NO alert rules at all
  integrations.cadvisor.enable = true;   # optional: scrape cAdvisor + enable its alerts
};

# Things the stack options do not expose — set on the services directly:
services.prometheus-nixlab.maintenance.exporters = {
  smartctl.devices = ["/dev/sda" "/dev/nvme0n1"];
  blackbox.httpTargets = ["https://example.com"];
  blackbox.sslTargets  = ["https://example.com"];
  blackbox.dnsTargets  = ["1.1.1.1"];     # enables blackbox-dns job + DNSResolutionFailure
  backup.enable = true;                   # enables backup exporter + its alerts
};
services.grafana-nixlab.extraDashboards = ["zfs-monitoring"];
services.grafana-nixlab.domain = "grafana.lan.example"; # adds nginx vhost, opens 80/443
services.grafana-nixlab.port = 3200;                    # ports: plain assignment on the service
```

---

## 4. Prometheus (`servc--prometheus-nixlab`)

Hand-rolled systemd unit (does **not** use upstream `services.prometheus`),
user/group hardcoded to `prometheus` (no `user`/`group` options). No
`nsops--` companion, no secrets. No `mkSslAssertion` *(pending, Stage 10d)*.

### 4.1 Options (`_internals/options.nix`)

| Option | Default | Notes |
|---|---|---|
| `enable` | — | |
| `port` | 9090 | |
| `listenAddress` | `"127.0.0.1"` | description text still mentions ComfyUI *(pending, Stage 11a)* |
| `domain` / `enableSSL` | null / false | nginx vhost via `_internals/extras/nginx.nix` (no extraConfig) |
| `dataDir` | `/var/lib/prometheus2` | holds `prometheus.yml`, `rules/`, `data/` |
| `retention` | `"15d"` | `--storage.tsdb.retention.time` |
| `package` | `pkgs.prometheus` | |
| `openFirewall` | true | |
| `enableNodeExporter` | true | custom unit, localhost:9100 |
| `extraScrapeConfigs` | `[]` | raw scrape_config attrsets appended last (stack uses it for ntfy, loki, grafana, alertmanager, alloy and the integrations) |
| `alertmanagerTargets` | `[]` | `host:port` list; empty = no alert delivery |
| `extraUsers` | `[]` | |
| `maintenance.enable` | false | master switch for exporters, alerts, textfile collector |
| `maintenance.exporters.systemd` | true | bool |
| `maintenance.exporters.blackbox.{enable,httpTargets,icmpTargets,sslTargets}` | true / `[]` / `["8.8.8.8" "1.1.1.1"]` / `[]` | |
| `maintenance.exporters.blackbox.dnsTargets` | `[]` | DNS servers to probe; non-empty also enables `DNSResolutionFailure` |
| `maintenance.exporters.blackbox.dnsQueryName` | `"example.com"` | name resolved by the DNS probe |
| `maintenance.exporters.smartctl.{enable,devices}` | true / `[]` | |
| `maintenance.exporters.backup.{enable,timestampFile,sizeFile}` | false / `/var/backups/last_backup_timestamp` / `/var/backups/last_backup_size` | `enable` also enables the backup alerts |
| `maintenance.exporters.backup.jobName` | `"backup"` | value of the `job_name` label on backup metrics |
| `maintenance.alerts.features.{traefik,containers,postgres}` | false | load the matching optional alert rules (set by the stack's `integrations.*`) |

### 4.2 Config assembly (`_internals/config.nix`)

Imports the sub-files and returns one attrset: tmpfiles (`dataDir` 0770, plus
`/var/lib/node_exporter` 0755 when maintenance), the `prometheus` user (extra
group `disk` when smartctl is on) and group, one merged `systemd.services`
(`prometheus-permissions`, `prometheus`, `prometheus-node-exporter` if enabled,
plus maintenance services — assigned once because the file isn't wrapped in
`mkMerge`), `services.prometheus.exporters`, `services.nginx`, and the firewall
(`mkFirewallPorts`).

### 4.3 The Prometheus unit (`services/prometheus.nix`)

`preStart` renders JSON→YAML with `remarshal` into `<dataDir>/prometheus.yml`
and `<dataDir>/rules/alerts.yml` (the two rule sets merged), then ensures
`<dataDir>/data`. Config: `scrape_interval`/`evaluation_interval` = 15 s,
`external_labels.monitor = "prometheus"`, `rule_files = ["<dataDir>/rules/*.yml"]`,
alertmanagers from `alertmanagerTargets`. `ExecStart` passes
`--storage.tsdb.path`, `--storage.tsdb.retention.time`, `--web.listen-address`,
console flags. Hardened with `mkServiceHardening { writablePaths = [dataDir]; }`.
Ordered `after prometheus-permissions.service` (template §8).

**Rules are only loaded when `maintenance.enable`**: `alerts.nix` is an empty
placeholder (`{ groups = []; }`) and `maintenance-alerts.nix` is imported only
when maintenance is on, as a function `{features}`. The feature set is
`maintenance.alerts.features // { backup = exporters.backup.enable; dns =
blackbox.enable && dnsTargets != []; }` (backup and dns are derived, so they
can't drift from the exporters). That file also holds the **recording rules**
the dashboards depend on (§8).

### 4.4 Scrape jobs (`scrape-configs.nix` + `extraScrapeConfigs`)

| Job | Target | Present when |
|---|---|---|
| `prometheus` | `localhost:<port>` | always *(→ `127.0.0.1`, pending Stage 9b)* |
| `node` | `localhost:9100` (labels `instance=localhost`, `alias=<hostname>`) | `enableNodeExporter` |
| `systemd` | `localhost:9558` | maintenance + exporters.systemd |
| `smartctl` | `localhost:9633` | maintenance + smartctl.enable |
| `blackbox-http` | httpTargets via module `http_2xx` | maintenance + blackbox + non-empty list |
| `blackbox-icmp` | icmpTargets via module `icmp` | same (default 8.8.8.8, 1.1.1.1) |
| `blackbox-ssl` | sslTargets via module `http_2xx` | same; source of `probe_ssl_earliest_cert_expiry` |
| `blackbox-dns` | dnsTargets via module `dns_a` | maintenance + blackbox + non-empty `dnsTargets` |
| `ntfy`, `loki`, `grafana`, `alertmanager` | `127.0.0.1:<resolved port>` | stack enabled |
| `alloy` | `127.0.0.1:<alloyPort>` | stack enabled + `enableAlloy` |
| `traefik`, `cadvisor`, `postgres` | `integrations.<x>.target` | `integrations.<x>.enable` |

Blackbox jobs use the standard relabel pattern (`__address__` → `__param_target`
→ `instance`, then `__address__ = localhost:9115`) via `mkBlackboxJob`.
Because `ServiceDown` matches every job except `prometheus|node`, all the stack
jobs above are automatically covered by it.

### 4.5 Exporters

- **node exporter** (`exporters/node.nix`): custom unit `prometheus-node-exporter`,
  `--web.listen-address=localhost:9100`, flags `--collector.{pressure,processes,systemd,hwmon,netclass,netdev}`,
  `--collector.filesystem.mount-points-exclude=^/(dev|proc|run|sys)($|/)`, and
  `--collector.textfile.directory=/var/lib/node_exporter` when maintenance is
  on. `MemoryMax=256M`, `TasksMax=10`, `SystemCallFilter=""` (deliberately
  disabled — intermittent syscall denials from hwmon/pressure/systemd collectors).
- **Upstream exporters** (`exporters/maintenance.nix` → `services.prometheus.exporters`):
  systemd `:9558`; blackbox `:9115` with a generated `blackbox.yml`
  (modules `http_2xx`, `icmp`, `tcp_connect`, `dns_a` — the DNS module resolves
  `dnsQueryName` against each `dnsTarget`); smartctl
  `:9633` with `CAP_SYS_RAWIO`, `DeviceAllow` for `/dev/sd*` and `/dev/nvme*`,
  `PrivateDevices = false`.
- **Backup exporter** (off by default): service `backup-status-exporter`
  loops every 300 s, reads `timestampFile` / `sizeFile`, writes
  `backup_job_last_success_timestamp` and `backup_job_size_bytes` to
  `/var/lib/node_exporter/backup_metrics.prom` for node_exporter's textfile
  collector. Values must be numeric (non-numeric content is skipped) and every
  sample carries `job_name="<jobName>"`. Your backup job must write epoch
  seconds to `timestampFile` on success; that producer is outside this stack.

---

## 5. Loki + Alloy (`servc--loki-nixlab`)

One module, two services, plus the optional maintenance layer. Has a
`nsops--` pattern slot but no secrets.

### 5.1 Options

| Option | Default | Notes |
|---|---|---|
| `enable`, `port` (3100), `listenAddress`, `domain`, `enableSSL`, `openFirewall`, `extraUsers` | standard | template §4 |
| `grpcPort` | 9096 | |
| `alloyPort` | 12345 | Alloy HTTP server (UI, `/metrics`), bound to `127.0.0.1`; default declared in `ports.nix` |
| `dataDir` | `/var/lib/loki` | |
| `retention` | `"744h"` | `limits_config.retention_period` |
| `package` / `alloyPackage` | `pkgs.grafana-loki` / `pkgs.grafana-alloy` | |
| `enableAlloy` | true | |
| `user` / `group` | `loki` / `loki` | |
| `maintenance.enable` | false | |
| `maintenance.logPath` | `/var/log/maintenance.jsonl` | JSON lines; an assertion rejects any path ending `.log` (it would also match the `/var/log/*.log` pipeline and be ingested twice) |

Uses `mkSslAssertion` plus the `logPath` assertion. Config is `lib.mkMerge [ {…main…} (nixlabLib.mkWalSelfHeal {…}) ]`.

### 5.2 Loki service

Generated `loki.yaml` (JSON→YAML via remarshal in `preStart`, installed 0660
into `<dataDir>`): `auth_enabled=false`; single-process; `common` with
filesystem storage (`chunks`, `rules` under dataDir), `replication_factor=1`,
inmemory ring; schema `v13` / `tsdb` from `2023-01-01`, `index.prefix=index_`,
period 24h; embedded results cache 100 MB; `max_query_series=10000`;
`max_query_lookback="720h"`; compactor with `retention_enabled=true`,
`retention_delete_delay=2h`, `delete_request_store=filesystem`; ingester WAL
enabled in `<dataDir>/wal` with `flush_on_shutdown=true`.
`TimeoutStopSec=5min` (default 90 s can SIGKILL mid-flush and corrupt the WAL).
`nixlabLib.mkWalSelfHeal` (see §12.1) adds automatic recovery from a corrupt WAL.
`after loki-permissions.service`. tmpfiles create `chunks`, `index`, `wal`.

> `max_query_lookback` (720 h = 30 d) is shorter than the default retention
> (744 h = 31 d). If you raise `retention`, raise the lookback too or you
> can't query the extra data.

### 5.3 Alloy service

Config is River, built in Nix and installed as `/var/lib/alloy/config.alloy`.
Runs `alloy run --server.http.listen-addr=127.0.0.1:<alloyPort> --storage.path=/var/lib/alloy/data …`,
user `alloy` (member of `systemd-journal`), `allowJIT = true`,
`after loki.service alloy-permissions.service`. The log line
`failed to (un)register collector … noop client` is Alloy's unused
remote-config service and is benign.

| Component | Purpose |
|---|---|
| `loki.write "local"` | pushes to `http://127.0.0.1:<port>/loki/api/v1/push` |
| `loki.relabel "journal"` | maps `__journal__systemd_unit` → `unit` and `__journal_priority_keyword` → `level` (the `level` rule depends on your Alloy version exposing that label; remove it and `"level"` from `label_keep` if it doesn't) |
| `loki.source.journal "systemd"` | `max_age=12h`, `relabel_rules`, labels `job=systemd-journal`, `host=<hostname>` |
| `loki.process "systemd"` | `static_labels` job/host; `label_keep` = job, host, unit, level |
| `local.file_match "varlogs"` / `loki.source.file "varlogs"` / `loki.process "varlogs"` | tails `/var/log/*.log`, label `job=varlogs` |
| *(maintenance only)* `local.file_match/loki.source.file/loki.process "maintenance"` | tails `logPath`; `stage.json` extracts timestamp, level, section, task, status, notes, user; `stage.labels` (level, section, status, user); `stage.static_labels` (`job=maintenance-log`, `host`); `stage.timestamp` RFC3339 |

Note on `stage.labels`: its map is *label → extracted-data key* (empty string =
same name), so constant labels must use `stage.static_labels`.

### 5.4 `maintenance-log` helper (maintenance only)

`environment.systemPackages` gets `pkgs.jq` and a `maintenance-log` command
built with `pkgs.writeShellScriptBin`, which prepends `jq coreutils gawk
gnugrep` to `PATH`, sets `MAINTENANCE_LOG` to the module's `logPath` **as a
default** (`${MAINTENANCE_LOG:-<logPath>}`, so a caller's override wins) and
embeds `maintenance-logger.sh`. `tmpfiles` creates the log as `0666 root root`.

**Interactive menu** (no arguments): lists **31 checklist sections** (§7.2),
`q` quick log (section `QUICK`; status is re-prompted until it is
`completed|skipped|failed`), `v` last 20 entries (colour by status, tolerant of
malformed lines), `s` stats (last-30-day counts by status/section computed with
`jq`, plus last-completion date per section), `x` exit. Numeric choices are
range-checked (`99`, `1abc` → "Invalid option").

**Non-interactive** (automation): `maintenance-log --section CODE --task TEXT
[--status completed|skipped|failed] [--notes TEXT]`. Unknown sections (not in
the list and not `QUICK`) and invalid statuses exit 2. Constraining these
matters because `section` and `status` become Loki **labels**.

**Record format** (JSON line, built with `jq -cn --arg …`, so any quotes or
backslashes in notes are safe): `{"timestamp","level":"info","section","task",
"status","notes","hostname","user"}`; `timestamp` is UTC RFC3339 (`…Z`).
*Contract:* these field names are parsed by the `stage.json` block in Alloy
(§5.3).

---

## 6. Alertmanager (`servc--alertmanager-nixlab`)

A **structured wrapper around the upstream** `services.prometheus.alertmanager`
(which provides `DynamicUser`, `StateDirectory`, `amtool check-config`,
`$ENV_VAR` expansion). No custom systemd unit, no `dataDir`/`user`/`group`, no
permissions oneshot.

### 6.1 Options

| Option | Default | Notes |
|---|---|---|
| `enable`, `port` (9093), `listenAddress`, `domain`, `enableSSL`, `package`, `openFirewall`, `extraUsers` | standard | `listenAddress` is passed **without** the port (upstream appends it) |
| `checkConfig` | `environmentFile == null` | amtool build-time check; auto-off when secrets are used |
| `environmentFile` | null | `KEY=VALUE` file → `EnvironmentFiles`, set by `nsops--alertmanager` |
| `clusterPeers` / `clusterPort` | `[]` / 9094 | HA gossip |
| `global.{resolveTimeout,smtpFrom,smtpSmarthost,smtpAuthUsername,smtpRequireTLS,slackApiUrl,pagerdutyUrl}` | `5m`, rest null | |
| `defaultReceiver` | `"null"` | catch-all; "null" = drop |
| `route.{groupBy,groupWait,groupInterval,repeatInterval}` | `[alertname instance]`, 30s, 5m, 4h | |
| `route.routes` | `[]` | submodules: `receiver, matchers, groupBy, groupWait, groupInterval, repeatInterval, continue, muteTimeIntervals` |
| `receivers` | `[{name="null";}]` | raw attrsets; use `$ENV_VAR` for secrets |
| `inhibitRules` | critical suppresses warning when `alertname`+`instance` equal | |
| `timeIntervals` | `[]` | mute windows |
| `extraConfig` | `{}` | deep-merged last (wins) |

Config assembled with `mkRoute` / `mkInhibitRule` helpers (camelCase → snake_case,
empty fields omitted) then `lib.recursiveUpdate … cfg.extraConfig`. `webExternalUrl`
is derived from domain/SSL or `listenAddress:port`.

### 6.2 Assertions

`mkSslAssertion`; every receiver referenced by `defaultReceiver`/routes must exist
in `receivers`; `environmentFile` set ⇒ `checkConfig` must be false; `clusterPeers`
non-empty ⇒ `openFirewall` true. Firewall: `mkFirewallPorts` plus `clusterPort`
when peers exist.

### 6.3 Behaviour in this stack

Routing: a root route to `ntfy` (default receiver) with one child route:
`severity="critical"` → `ntfy-critical` (`groupWait=10s`, `repeatInterval=1h`,
ntfy priority 5, tag `rotating_light`); everything else uses `ntfy`
(`tags=warning`). The default inhibit rule still suppresses a warning when a
critical fires for the same `alertname`+`instance`. Notification bodies are
rendered by ntfy from the Alertmanager JSON payload using the templates in
§3.2 item 6; `notifications.formatMessages = false` restores the raw JSON
body. If ntfy rejects a template (HTTP 400) Alertmanager logs a notify error
(`journalctl -u alertmanager | grep -i notify`).

---

## 7. Alert rules (`maintenance-alerts.nix`)

Loaded only when `prometheus-nixlab.maintenance.enable = true`.

### 7.1 How the file works

- **`withCondition`** wraps every *alert* (not recording) rule and adds a
  `condition` label containing the whitespace-squashed PromQL plus ` (for <dur>)`.
  Labels propagate to the `ALERTS` series, so Grafana can show *why* something
  fired without opening Prometheus, and it can never drift from the real expr.
- **`fsFilter`** — excludes `tmpfs|overlay|squashfs|ramfs|devtmpfs|nsfs|erofs|fusectl|fuse.gvfsd-fuse|fuse.portal`
  and mountpoints `/nix/store|/run/.*` (bind mount would double-alert).
- **`netFilter`** — excludes `lo|veth.*|docker.*|br-.*|virbr.*`.
- Every alert carries labels `severity` (`warning|critical`), `category`, and
  `checklist_section` (e.g. `I.1`). Warning bands are written as ranges
  (`< 20 >= 10`, `> 80 <= 90`) so warning and critical don't double-fire.
- **Feature gating.** `maintenance-alerts.nix` is a function of `{features}`.
  A rule may carry `requires = "<feature>";`; `isEnabled` keeps it only when
  `features.<feature>` is true, `stripGate` removes the attribute before output
  (Prometheus would reject unknown fields) and `prune` drops groups left empty.
  Features: `dns` and `backup` (derived from the exporters), `traefik`,
  `containers`, `postgres` (set by the stack's `integrations.*`).
- Hand-fixed past bugs are documented inline (CPUThrottling label matching,
  HighIOWait unreachable threshold, ContainerRestartLoop firing for everything,
  cert-expiry unit mismatch).

### 7.2 Alert catalogue (34 base alerts + 1 backup-only, 8 groups)

**†** = feature-gated (`requires`); loads only when the feature in the last
column is on. 27 alerts load by default.

| Group (interval) | Alert | Sev | Section | Fires when | For | Gate |
|---|---|---|---|---|---|---|
| hardware_health (30s) | HighCPUTemperature | warn | I.1 | coretemp/k10temp/amdgpu/nvme sensor 80–90 °C | 5m | |
| | CriticalCPUTemperature | crit | I.1 | same sensors > 90 °C | 2m | |
| | CPUThrottling | warn | I.1 | cores < 60 % of max freq while > 50 % busy (per host) | 10m | |
| | FanSpeedLow | warn | I.1 | fan < 1000 RPM **and** host > 55 °C | 5m | |
| | LowDiskSpace | warn | I.2 | free 10–20 % | 5m | |
| | CriticalDiskSpace | crit | I.2 | free < 10 % | 2m | |
| | DiskWillFillIn24h | warn | I.2 | `predict_linear` 6 h → < 0 in 24 h and < 50 % free | 1h | |
| | HighInodeUsage | warn | I.2 | inodes free < 20 % | 5m | |
| | NetworkInterfaceErrors | warn | I.3 | rx/tx errors > 10/s | 5m | |
| | NetworkPacketDrops | warn | I.3 | rx/tx drops > 50/s | 5m | |
| os_health (1m) | OutOfMemoryKills | crit | II.5 | `increase(node_vmstat_oom_kill[1h]) > 0` | — | |
| | ClockDrift | warn | II.5 | `abs(offset) > 0.1 s` | 10m | |
| | ClockNotSynced | warn | II.5 | `node_timex_sync_status == 0` | 15m | |
| | HighCPULoad | warn | II.6 | load5 / cores > 0.7 | 10m | |
| | HighMemoryUsage | warn | II.6 | > 85 % | 5m | |
| | SwapUsage | warn | II.6 | > 50 % | 5m | |
| | HighIOWait | warn | II.6 | avg iowait > 20 % | 10m | |
| storage_backups (5m) | BackupJobFailed † | crit | III.7 | `time() - backup_job_last_success_timestamp > 24h` | 1h | `backup` |
| | BackupSizeAnomaly † | warn | III.7 | > 30 % change vs 7 d ago | 1h | `backup` |
| | BackupMetricsMissing † | warn | III.7 | `absent(backup_job_last_success_timestamp)` | 1h | `backup` |
| network_security (1m) | DNSResolutionFailure † | crit | IV.12 | `probe_success{job="blackbox-dns"} == 0` | 3m | `dns` |
| | HighNetworkLatency | warn | IV.12 | ICMP > 100 ms | 5m | |
| | CertificateExpiringSoon | warn | IV.13 | 7–30 days left | 1h | |
| | CertificateExpiringCritical | crit | IV.13 | < 7 days | 1h | |
| service_health (30s) | HostDown | warn | V.14 | `up{job="node"} == 0` | 5m | |
| | ServiceDown | crit | V.14 | `up{job!~"prometheus\|node"} == 0` | 2m | |
| | SystemdServiceFailed | warn | V.14 | `node_systemd_unit_state{state="failed"} == 1` | 5m | |
| | PostgresReplicationLag † | warn | V.15 | `pg_replication_lag_seconds > 300` | 5m | `postgres` |
| | HighHTTPErrorRate † | warn | V.16 | traefik 5xx ratio > 5 % and > 0.05 req/s | 5m | `traefik` |
| container_health (30s) | ContainerRestartLoop † | warn | VI.18 | `changes(container_start_time_seconds[15m]) > 2` | 5m | `containers` |
| | ContainerHighMemory † | warn | VI.18 | > 90 % of a non-zero limit | 5m | `containers` |
| monitoring_stack (1m) | PrometheusNoRecentSamples | crit | VII.21 | `absent_over_time(up{job="prometheus"}[10m])` | 5m | |
| | PrometheusSamplesOutOfBounds | crit | VII.21 | out-of-bounds sample counter increases | 10m | |
| | PrometheusHeadInFuture | crit | VII.21 | TSDB head > 1 h ahead of wall clock | 5m | |
| | PrometheusRuleEvaluationFailures | warn | VII.22 | rule eval failures increase | 5m | |

Section codes now exist in the `maintenance-log` section list (`VII.21 Metrics
Coverage`, `VII.22 Alerting`). *Contract:* every `checklist_section` used by an
alert must appear in the CLI's `CHECKLIST_SECTIONS`; check with
`grep -oh 'checklist_section = "[^"]*"' …/maintenance-alerts.nix | cut -d'"' -f2 | sort -u`
against `grep -oE '"[IVX]+\.[0-9]+:' …/maintenance-logger.sh | tr -d '":' | sort -u`
(`comm -23` must print nothing).

**Optional-exporter alerts** are gated so they only load when their data
source exists. To enable one: set the matching `integrations.<x>.enable` in the
stack (traefik, cadvisor, postgres), `blackbox.dnsTargets` (DNS) or
`exporters.backup.enable` (backup). The exporters themselves (traefik metrics
entry point, `services.cadvisor`, `services.prometheus.exporters.postgres`) are
host concerns; the stack only connects them.

---

## 8. Recording rules (group `maintenance_metrics`, 1m)

Also only present with `maintenance.enable`. Dashboards depend on them.

| Record | Meaning |
|---|---|
| `system:health_score:percentage` | `clamp_min(100 − 20×firing critical − 5×firing warning, 0)` |
| `system:alerts_by_category:count` | firing alerts by `category` |
| `system:alerts_by_section:count` | firing alerts by `checklist_section` |
| `node:disk_usage:percentage` | % used per filesystem (uses `fsFilter`) |
| `node:memory_usage:percentage` | % memory used |
| `node:cpu_usage:percentage` | % CPU non-idle per instance |

---

## 9. Grafana (`servc--grafana-nixlab`)

Hand-rolled unit (not upstream `services.grafana`), `sqlite3`, config entirely
via `GF_*` environment variables.

### 9.1 Options

| Option | Default | Notes |
|---|---|---|
| `enable`, `port` (3101), `listenAddress`, `domain`, `enableSSL`, `dataDir` (`/var/lib/grafana`), `package`, `openFirewall`, `user`/`group` (`grafana`), `extraUsers` | standard | |
| `allowAnonymous` | false | anonymous Viewer role |
| `credentialsFile` | null | **string** path to raw admin password → `GF_SECURITY_ADMIN_PASSWORD__FILE`. Only applied when Grafana first creates its DB. |
| `secretKeyFile` | null | → `GF_SECURITY_SECRET_KEY__FILE`; warning emitted if null. Changing it on an existing DB makes stored secrets unreadable. |
| `dashboards` | attrset of `{path, folder, editable, updateInterval}` | module-owned base set: `maintenance` → `maintenance-checklist.json`, `system-overview-v5` → `system-overview-v5.json` |
| `extraDashboards` | `[]` | names of extra JSON files in the module's `dashboards/` dir (e.g. `"zfs-monitoring"`); placed in folder `maintenance`, editable |
| `provisioning.datasources` | `[]` | `{name, type, url, access="proxy", isDefault, editable, jsonData}`; `type` is lower-cased (plugin ids are case-sensitive) |

Strings (not `path`) for the two secret options so literals never get copied
into the world-readable Nix store.

### 9.2 Assertions

`mkSslAssertion`; every `extraDashboards` name must exist as a file; no
`extraDashboards` name may clash with a base `dashboards` key.

### 9.3 Startup pipeline (`grafana.service`)

Env: `GF_PATHS_{DATA,LOGS,PLUGINS,PROVISIONING}` under dataDir, console+file
logging, sqlite at `<dataDir>/data/grafana.db`. Hardened with
`RestrictAddressFamilies` extended to `AF_UNIX` (backend plugins talk over unix
sockets). `after grafana-permissions.service`.

`ExecStartPre`:
1. **`+grafana-setup` (root)** — deletes dashboard dirs and provisioning YAMLs
   no longer in the dashboard set; SQL-cleans `grafana.db` (removes provisioned
   dashboards whose provider is gone, whose DB `uid` differs from the JSON `uid`,
   and orphaned folders); creates provisioning directories.
2. **`grafana-provision` (grafana user)** — renders datasources JSON→YAML into
   `provisioning/datasources/datasources.yaml`; for each dashboard copies the JSON
   to `<dataDir>/dashboards/<name>/dashboard.json` and writes a file provider
   `provisioning/dashboards/<name>.yaml` (folder, `updateIntervalSeconds`,
   `allowUiUpdates`).

Because of the uid-mismatch cleanup, **give every dashboard JSON a stable
`uid`** and don't change it casually.

### 9.4 Dashboards

| File | uid | What it is |
|---|---|---|
| `maintenance-checklist.json` | *(none; uid + Loki panels pending, Stage 12c)* | "System Maintenance Checklist". Health gauge, active alerts by severity, resource overview; for each checklist family I–VI an "Automated Checks" table (query `ALERTS{checklist_section=~"<family>\\..*", alertstate="firing"}`; the pattern was corrected in Stage 1, the old `<family>\\.*` form never matched `I.1`-style codes) next to a "Manual Tasks" markdown checklist (weekly/monthly/quarterly, with commands); storage and cert-expiry timeseries, service uptime matrix, weekly/monthly/quarterly summaries, alert history. |
| `system-overview-v5.json` | `system-maintenance-overview-v5` | "System Monitoring & Maintenance Dashboard v5". Hidden vars `DS_PROMETHEUS` (datasource) and `prometheus_url` (constant `http://localhost:9090`). Rows: Health overview (health score, alerts by severity, failed units, hottest sensor, uptime, kernel, root FS, RAM, swap, **active-alerts table showing the `condition` label** with link to Prometheus, firing by category/section); CPU; Memory; Storage & Disk (usage, inodes, IO, busy %, **time-until-disk-full**); Network; Hardware & System info (temps, CPU freq, clock offset, failed units); Service monitoring (uptime history, alert counts, alert timeline). Collapsed rows: Monitoring Stack Health (scrape targets, TSDB, rule failures), Containers, Web & Network Probes (traefik, blackbox), Backups & Certificates, Maintenance Checklists. Plus Extended Metrics. Annotation: firing alerts. |
| `zfs-monitoring.json` | `zfs-pool-monitoring` | "ZFS Pool Monitoring" (opt-in). Var `zpool`; rows for pool state, dataset I/O, ARC, ZIL, mounted-dataset space. Uses `node_zfs_*` metrics. |

### 9.5 Adding a dashboard

1. Drop `<name>.json` in `modules/nixos/monitoring/grafana/dashboards/`
   (include a stable `uid`; reference the default datasource or the
   `${DS_PROMETHEUS}` variable pattern).
2. `git add` it (flakes only see tracked files).
3. Host: `services.grafana-nixlab.extraDashboards = ["<name>"];` — or add it to
   the `dashboards` default for all hosts.

---

## 10. ntfy (`servc--ntfy-nixlab`)

Hand-rolled unit; server config built as a Nix attrset → JSON → YAML
(`server.yml`, 0640) in `preStart` (same pattern as Loki).

| Option group | Options |
|---|---|
| standard | `enable`, `port` (2586), `listenAddress`, `domain`, `enableSSL`, `dataDir` (`/var/lib/ntfy`), `package` (`pkgs.ntfy-sh`), `openFirewall`, `user`/`group` (`ntfy`), `extraUsers` |
| cache | `cacheDuration` (`12h`), `cacheFile` (`""` = in-memory) |
| `attachments` | `enable` (false), `sizeLimit` 15M, `totalSizeLimit` 5G, `expiryDuration` 3h — **requires `cacheFile`** (asserted) |
| `rateLimit` | `globalTopicLimit` 15000, `subscriberRateLimit` false |
| `auth` | `enable` (false), `defaultAccess` (`deny-all` default; also `read-write|read-only|write-only`); `auth-file = <dataDir>/user.db` |
| `enableWebUI` | true |
| `smtp` | `enable`, `listenAddress` `0.0.0.0:25`, `domain` (asserted when enabled), `addrPrefix`; opens port 25 |
| `firebaseKeyFile` | null; passed via `Environment=NTFY_FIREBASE_KEY_FILE=…` |

Fixed settings: `enable-signup=false`, `enable-metrics=true`, visitor request
limits, `visitor-subscription-limit=30`. nginx vhost has SSE-friendly settings
(`proxy_buffering off`, 1800 s timeouts, `client_max_body_size 50M`). No
`nsops--ntfy` module exists.

In this stack ntfy is **unauthenticated** (auth off) and Alertmanager publishes
with no credentials. If you enable `auth`, you must also give the Alertmanager
webhook receiver basic-auth credentials (via `environmentFile` + `$VAR`).

---

## 11. Secrets (`nsops--*`)

Follow template §11 exactly. Only `servc--*` modules never touch `sops.*`.

| Joiner | Secrets file | Secrets | Sink |
|---|---|---|---|
| `nsops--grafana` | `sops/grafana.yaml` | `GRAFANA_ADMIN_PASSWORD`, `GRAFANA_SECRET_KEY` (owner/group = grafana, restarts `grafana.service`) | `credentialsFile`, `secretKeyFile` (`lib.mkDefault` to the sops paths) |
| `nsops--alertmanager` | `sops/alertmanager.yaml` | `ALERTMANAGER_ENV` with `format = "dotenv"`, owner left root (upstream unit uses `DynamicUser`; systemd reads `EnvironmentFile` as root), restarts `alertmanager.service` | `environmentFile` |

Intended Alertmanager env keys (per the file's own comment): `SLACK_WEBHOOK_URL`,
`SLACK_WEBHOOK_URL_CRITICAL`, `PAGERDUTY_ROUTING_KEY`, `SMTP_PASSWORD`,
`NTFY_PASSWORD`. Referenced in receivers as `$KEY`.

Loki, Prometheus and ntfy have no joiners. Per the README, `sops.age.keyFile`
is set once globally in `hosts--core--sops` (age key at
`/var/lib/sops-nix/key.txt`, provisioned before first switch); recipients are
in `.sops.yaml`. Joiners never set it.

---

## 12. Cross-cutting conventions (from the module template)

Every monitoring module follows template §3–§8, §10:

- Dedicated `<name>-permissions.service` oneshot (`mkDataDirPermissionsService`)
  is `requiredBy` the main unit and in its `after`: present for `loki`, `alloy`,
  `grafana`, `prometheus`, `ntfy`; absent for Alertmanager (DynamicUser).
- `mkServiceHardening` first, unit-specific keys `//` on top. Relaxations used:
  `allowJIT` (Alloy), `RestrictAddressFamilies` (Grafana, node exporter),
  `SystemCallFilter=""` (node exporter).
- Firewall via `mkFirewallPorts`; nginx via `mkNginxVirtualHost` (empty when
  `domain == null`). Loki opens its gRPC port when `domain == null` *(changes,
  Stage 9a: new `openGrpcPort`, default false)*.
- Port defaults via `systm--ports-<name>` modules in `modules/ports.nix`, all `lib.mkDefault` (confirmed): loki 3100 + gRPC 9096 + `alloyPort` 12345, grafana 3101, prometheus 9090, alertmanager 9093, ntfy 2586. Precedence: host plain assignment > ports.nix `mkDefault` > module's own `default`.
- `mainUser` + `extraUsers` group membership block in every module.
- **Stack-level rules** (what Stages 4–8 enforce): the stack reads resolved
  ports instead of owning them; tunables are `mkDefault`, wiring is plain; it
  defines no units or users; cross-module data goes through an option on the
  consuming module (`extraScrapeConfigs`, `provisioning.datasources`,
  `alerts.features`, …).
- `# REQUIRED:` / `# OPTIONAL:` comments on options in Loki and ntfy; Grafana,
  Alertmanager and Prometheus options are documented via `description` only.

Startup ordering: `*-permissions` → `loki` → `alloy`; `prometheus-permissions`
→ `prometheus`; `grafana-permissions` → `grafana`; `ntfy-permissions` → `ntfy`.
No unit declares an ordering dependency between Prometheus, Alertmanager and
ntfy (retries cover it).

### 12.1 `nixlabLib` helpers as used here

Signatures are in template §8; the full source is `flake/nixos-lib.nix`.

| Helper | Behaviour that matters | Used by |
|---|---|---|
| `mkServiceHardening` | Base: `NoNewPrivileges`, `PrivateTmp`, `ProtectSystem=strict`, `ProtectHome`, `MemoryDenyWriteExecute`, `SystemCallFilter=@system-service`, `ReadWritePaths`; `RestrictAddressFamilies=[INET INET6]` unless `allowNetwork=false`; device/kernel lockdown unless `allowDevices`; `allowJIT` sets `MemoryDenyWriteExecute=false` and `SystemCallFilter=""` | loki, alloy (`allowJIT`), grafana (+`AF_UNIX`), prometheus, node exporter (+`AF_NETLINK`/`AF_UNIX`, filter cleared), ntfy |
| `mkNginxVirtualHost` | `{}` when `domain == null`; else vhost with `forceSSL`/`enableACME = enableSSL`, `proxyPass http://<listenAddress>:<port>`, `proxyWebsockets` (default **true**), standard Host/X-Forwarded headers, then `extraConfig` | all five (Prometheus passes no `extraConfig`) |
| `mkFirewallPorts` | `[servicePort]` only if `domain == null` **and** `listenAddress != "127.0.0.1"` (exact string match); `[80 443]` if `domain` set; `extraPorts` always appended | all five; Loki adds gRPC, Alertmanager adds `clusterPort` when peers, ntfy adds 25 when SMTP |
| `mkSslAssertion` | `enableSSL` requires `domain` | loki, alertmanager, grafana, ntfy (not prometheus) |
| `mkDataDirPermissionsService` | Root oneshot, `RequiresMountsFor=[dataDir]`, `chown -R user:group dataDir`; wired with `requiredBy` | loki, alloy, grafana, prometheus, ntfy |
| `mkWalSelfHeal` | see below | loki only |

**`mkWalSelfHeal` in detail (Loki).** Returns a config fragment (merged via
`mkMerge`) that:

1. Adds a start limit to `loki.service` (`StartLimitBurst=3` in
   `StartLimitIntervalSec=300`) and `OnFailure=loki-wal-recover.service`.
   With Loki's `Restart=on-failure`, `RestartSec=10s`, three crashes trip it in
   about 30 s.
2. `loki-wal-recover.service` (root oneshot) acts only if the last 15 min of
   `loki.service` journal matches the case-insensitive regex
   `segments are not sequential|wal.*corrupt|corrupt.*wal|checkpoint.*corrupt`.
   Unrelated failures leave data alone.
3. It moves `<dataDir>/wal` to `wal.broken-<timestamp>`, recreates an empty WAL
   (0770 `loki:loki`), `reset-failed`s and restarts Loki. It keeps at most 2
   quarantined copies and runs at most once per hour (stamp in
   `/var/lib/loki-wal-recover/last-recovery`), so a persistent fault can't loop.
4. Cost: anything that existed only in the WAL (the last few minutes) is lost.
   It covers WAL corruption only, not chunk/index damage, and it only triggers
   on start-failure loops, so it would not catch Prometheus
   "running but rejecting samples" incidents. If it fires often, find the cause;
   check for `wal.broken-*` directories next to the WAL.

---

## 13. Changelog and open items

IDs **G1–G17** are the numbered gotchas from the first version of this
document; the guide's stage titles refer to them. **N1–N4** were found while
applying the fixes.

### 13.1 Resolved (Stages 1–8)

| ID | Was | Fixed in | Now |
|---|---|---|---|
| G1 | Checklist dashboard regex `I\.*` never matched `I.1` | Stage 1 | `I\..*` in all six family tables |
| G2 | Maintenance logs had no `job`/`host` label (`stage.labels` misuse) | Stage 3 | `stage.static_labels` for `job`/`host`; `stage.labels` for the JSON fields |
| G3 | `unit` label for journal logs never existed | Stage 3 | `loki.relabel "journal"` + `relabel_rules`; `level` from `__journal_priority_keyword` *(re-confirm on your Alloy version)* |
| G4 | `/var/log/maintenance.log` ingested twice | Stage 3 | log renamed `*.jsonl` + assertion forbidding `.log` |
| G5 | Stack `ports.*` tied with `ports.nix` and drifted from resolved ports | Stages 4–5 | stack reads resolved ports; tunables are `mkDefault` |
| G9 | Loki, Grafana, Alertmanager, Alloy not scraped | Stage 6 | stack adds the four jobs (+ ntfy as before) |
| G8 | Alerts without data sources (traefik, cAdvisor, postgres, DNS, backup) always loaded | Stage 7 | feature-gated; DNS job added; `integrations.*` connect scrape + alert |
| G10 | Backup metrics lacked `job_name`; missing file made backup alerts silent | Stage 7c | labelled and validated; `BackupMetricsMissing` added |
| G11 | ntfy messages were raw Alertmanager JSON; all severities equal | Stage 8 | templated messages; critical → priority 5 receiver |
| G17 (part) | `VII.19` didn't exist in the CLI; `show_stats` ignored the cutoff; unescaped JSON | Stages 2, 7d | codes aligned (VII.21/22); stats use a real 30-day cutoff; `jq -cn` builds JSON |
| N2 | Wrapper forced `MAINTENANCE_LOG`, ignoring caller override | Stage 2 | `${MAINTENANCE_LOG:-<logPath>}` default form |

### 13.2 Open items

| ID | Issue | Planned in |
|---|---|---|
| G6 | **By design:** no alert or recording rules load unless `prometheus.maintenance.enable = true`; dashboards' health/category/section panels need it | documented; no change planned |
| G7 | Possible duplicate `proxy_http_version` in nginx vhosts (helper already sets `proxyWebsockets`, modules repeat the directives); never exercised because no domains are set | Stage 10b *(verify first)* |
| G12 | Every scrape target is `localhost`: each host monitors only itself | Stage 14 (optional) |
| G13 | Stack binds everything to `0.0.0.0` with firewall open; Loki/Prometheus/Alertmanager/ntfy are unauthenticated | Stage 9b–c (backend loopback), 9e (ntfy auth, optional) |
| G14 | Loki gRPC (9096) firewalled open whenever `domain == null`, and not bound to `listenAddress` | Stage 9a |
| G15 | With a domain and `listenAddress = 0.0.0.0`, nginx proxies to `http://0.0.0.0:<port>`; loopback detection only matches the exact string `127.0.0.1` | Stage 10c |
| G16 | `prometheus_url` constant in `system-overview-v5` is `http://localhost:9090` | Stage 12b |
| G17 (rest) | Prometheus `listenAddress` text says "ComfyUI"; Grafana assertion path text; `max_query_lookback` (720 h) not tied to `retention`; systemd exporter redundant with node_exporter's collector; Prometheus has no `mkSslAssertion`; template §8 lacks `mkWalSelfHeal` | Stages 10d, 11a–f, 13b |
| — | Datasource uids not provisioned; `maintenance-checklist.json` has no `uid` and no Loki panels | Stage 12a, 12c |
| — | Implicit cross-module contracts are not written at both ends | Stage 13a |

### 13.3 Notes from applying the fixes

- **N1** Alloy logs `failed to (un)register collector … noop client` at error
  level on every start/stop. It's the unused remote-config service, benign,
  and present before the changes.
- **N3** Loki's `/ready` returns 503 for ~15 s after every start; a single
  health probe right after a restart can report FAIL. The smoke script retries
  (`--retry 3 --retry-delay 3 --retry-all-errors`).
- **N4** Stage 2 test entries (including one stray `t2` written before the
  wrapper fix) remain in `/var/log/maintenance.log` and are tailed as
  `job="varlogs"`; harmless, they age out of Loki after retention. After
  Stage 3 new records go to `/var/log/maintenance.jsonl`.
- Journal `unit`/`level` labels fill in only as new journald entries arrive
  after an Alloy restart; use a deterministic test (`systemd-cat -t x -p
  warning echo marker`, then query `{job="systemd-journal"} |= "marker"`)
  instead of relying on a particular unit having logged recently.

---

## 14. Prompts you can hand to Claude

Attach this file (plus `nixlab-module-template.md` for code generation, and
`nixlab-monitoring-fix-guide.md` when continuing the work) and fill in the
blanks.

**Understand / debug**

> Using the attached nixlab monitoring stack reference, explain why
> `<symptom, e.g. "no alerts reach my phone" / "Grafana panel X is empty">`.
> Trace the data path through §1 and §3.2, check §13.2 for related open items,
> and tell me which commands to run (`journalctl -u <unit>`, curl endpoints,
> `promtool`, `amtool`, etc.) to confirm.

**Continue the fix guide**

> The attached guide says Stages 1–8 are done. Walk me through Stage `<N>`:
> show the exact edits against the current code described in the reference
> (§3, §4, §5), keep to the coupling rules (R1–R7), and give the verify
> commands and commit message.

**Add an alert**

> Add an alert `<Name>` to `maintenance-alerts.nix` in group `<group>`:
> `<condition in plain English>`, severity `<warning|critical>`, `for <dur>`,
> category `<cat>`, `checklist_section` `<N.n>` (must exist in the CLI section
> list). Follow the existing style (`fsFilter`/`netFilter`, `$labels`/`$value`
> annotations, banded warning range if a critical twin exists). If it depends
> on an exporter the stack doesn't provision, add `requires = "<feature>";`,
> the option/derivation that sets the feature, and the stack `integrations`
> entry that scrapes it.

**Add an exporter / scrape job**

> Add a Prometheus scrape job for `<service>` at `<host:port>` via the stack's
> `extraScrapeConfigs` (use the `scrapeJob`/`loopback` helpers and the
> resolved `port.*` attrs; never hardcode ports). Mention whether `ServiceDown`
> already covers it and which Grafana panel to extend in `system-overview-v5.json`.

**Add a dashboard**

> Create a Grafana dashboard JSON `<name>` for `<metrics/logs>` in the format
> used by the existing dashboards (stable `uid`, `${DS_PROMETHEUS}` datasource
> variable, schemaVersion 36, dark style, 30 s refresh) and tell me the
> `extraDashboards` line to enable it.

**Add a service to the stack**

> Generate a new `servc--<service>-nixlab` module (and `nsops--` joiner if it
> has secrets) per the nixlab module template, then show the exact edits to
> `stacks/monitoring.nix`: add it to `port`, a `mkDefault` basics block,
> and the cross-wiring (scrape job, datasource, receiver) through existing
> injection options only.

---

*Reference source (state after Stage 8): `stacks/monitoring.nix`; `modules/nixos/monitoring/{loki,
prometheus,alertmanager,grafana,ntfy}` (including `prometheus/_internals/*`,
`loki/maintenance-logger.sh`, and the three Grafana dashboard JSON files);
`sops/{grafana,alertmanager}.nix`. Cross-referenced against
`modules/ports.nix`, `flake/nixos-lib.nix` (full `nixlabLib` source), the repo
`README.md`, `nixlab-module-template.md` for shared conventions, and the
command output from applying Stages 0–3 of `nixlab-monitoring-fix-guide.md`.*
