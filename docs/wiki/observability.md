# Nixlab Observability Stack — Architecture & Reference

> **Scope.** Everything under `modules/nixos/observability/`, `stacks/observability.nix`, `sops/{alertmanager,grafana}.nix`, `modules/ports.nix` (monitoring entries), `flake/nixos-lib.nix` (helpers the stack uses), `flake/ci/observability-checks.nix` + `flake/ci/_tests/`, `bin/mon-*.sh`, and `docs/runbooks/`.
> **Basis.** Written from the code as provided on 2026-11-01, **after applying `tools/observability-cleanup.py`** (removal of hub/agent wording, `MaintenanceOverdue`, stale comments). Not available when writing: the per-host files (`hosts/<host>.nix`) and `modules/nixos/homepage-dashboard/_internals/service-registry.nix`; anything that depends on them is marked *(not in the provided code)*.
> **Companion docs.** `docs/runbooks/*.md` (one page per alert), `docs/secrets-rotation.md` (password rotation design), `docs/design-review.md` (repo structure suggestions).
> **Staleness rule.** If this file and the code disagree, the code wins. Section 16 lists open issues.

---

## Table of Contents

0. [Context card (paste this into an LLM prompt)](#0-context-card)
1. [Overview](#1-overview)
2. [Design principles and why](#2-design-principles-and-why)
3. [Hosts and default configuration](#3-hosts-and-default-configuration)
4. [File map](#4-file-map)
5. [The aggregator: `stack--observability`](#5-the-aggregator-stack--observability)
6. [Component reference](#6-component-reference)
7. [Alerting reference](#7-alerting-reference)
8. [Data flows](#8-data-flows)
9. [Secrets](#9-secrets)
10. [Runtime layout](#10-runtime-layout-what-is-where-on-a-host)
11. [Shared helpers (`nixlabLib`)](#11-shared-helpers-nixlablib)
12. [Resilience mechanisms](#12-resilience-mechanisms)
13. [CI and testing](#13-ci-and-testing)
14. [Operations](#14-operations)
15. [Extending the stack](#15-extending-the-stack)
16. [Open issues and sharp edges](#16-open-issues-and-sharp-edges)
17. [Quick reference](#17-quick-reference)
18. [Appendix: illustrative host configuration](#appendix-illustrative-host-configuration)

---

## 0. Context card

*Self-contained summary. If you only paste one section into a prompt, paste this one; paste the whole file for deep work.*

**What it is.** A self-hosted observability stack in a NixOS flake (`nixlab`, flake-parts + import-tree, "Dendritic" self-registering modules). Components: **Prometheus** (metrics + alert rules), **Alertmanager** (routing/inhibition), **ntfy** (push notifications), **Loki** (logs + LogQL ruler), **Grafana Alloy** (log shipper), **Grafana** (dashboards), plus **node_exporter**, **smartctl_exporter**, **blackbox_exporter**, and a **maintenance-log** helper that records manual maintenance tasks as JSON lines.

**Shape.** Each component is an *atomic* NixOS module (`servc--<x>-nixlab`, options at `services.<x>-nixlab.*`) with no knowledge of its siblings. All cross-service wiring (datasources, scrape jobs, receivers, ruler → Alertmanager, uids, URLs, firewall, backups) lives in **one aggregator module** `stack--observability` (`stacks/observability.nix`, options at `services.nixlab-observability.*`). A host enables `services.nixlab-observability.enable = true` and gets everything.

**Hosts.** Seven independent hosts (`nixnas1`, `nixnas2`, `nixace`, `nixsun`, `nixtop`, `nixvat`, `nixzen`, all `x86_64-linux`, static IPs 10.0.0.200–204, 251, 252). Every host runs the whole stack for itself; nothing depends on another host. `hosts--profl--base` enables it everywhere with: scrape interval 60 s, Prometheus retention 7 d / 4 GB, Loki retention 168 h (maintenance log 2 years), maintenance alerts + maintenance log on, ntfy auth on, `access.expose = [grafana ntfy prometheus]` but **`access.interfaces` empty, so everything is loopback-only** unless a host sets interfaces.

**Data flow.** exporters → Prometheus → (rules) → Alertmanager → webhook → ntfy topic `alerts` → phone/browser. Journald + `/var/log/*.log` + maintenance log → Alloy → Loki → (ruler alerts) → Alertmanager. Grafana reads Prometheus, Loki, Alertmanager (uids `prometheus`, `loki`, `alertmanager`).

**Config generation pattern.** Nix attrset → `builtins.toJSON` → `remarshal` → YAML written into the service's `dataDir` (default `/data/<svc>`) at service start (`preStart`/`ExecStartPre`). Config is regenerated on every start; do not hand-edit generated files.

**Ports.** ntfy 2586, Loki 3100 (gRPC 9096 loopback), Grafana 3101, Prometheus 9090, Alertmanager 9093, node 9100, smartctl 9633, blackbox 9115, systemd-exporter 9558 (off), Alloy 12345 (loopback). Defaults come from `modules/ports.nix` via `lib.mkDefault`; the stack never sets port numbers.

**Exposure model.** Everything binds loopback unless a service is listed in `access.expose` *and* `access.interfaces` is non-empty (then `0.0.0.0` + per-interface firewall rules on the named wired interfaces). `openFirewall` (all interfaces) defaults to false. Alertmanager always posts to the *local* ntfy.

**Alerts.** ~62 Prometheus alert rules in `_internals/maintenance-alerts.nix`, grouped by maintenance-checklist section (labels `severity`, `category`, `checklist_section`), plus 4 Loki-ruler alerts defined in the stack. Core groups (stack self-health, recording rules) always load; the rest load only if `services.nixlab-observability.prometheus.maintenance.enable = true` (set by `hosts--profl--base`). Every Prometheus alert needs `docs/runbooks/<Alert>.md` or an entry in `docs/runbooks/_todo.txt` (CI-enforced). Deployed alerts carry a `condition` label (own expr + `for`) and a `runbook` annotation (GitHub URL).

**Resilience.** Prometheus can stay "healthy" while storing nothing (for example after a clock jump). Mitigations: services order after `time-sync.target` (which `hosts--profl--base` makes wait for NTP); `prometheus-tsdb-guard` timer quarantines a wrong-time WAL/head; `mkWalSelfHeal` quarantines a corrupt WAL after crash loops (Prometheus and Loki); `absent_over_time` self-alert; inhibition of all `observability` alerts while `PrometheusNoRecentSamples` fires.

**Verification.** `nix flake check` (promtool config/rules/tests, amtool, dashboard lint, shellcheck, runbook coverage); on a host `bin/mon-check.sh [--fire-test]`; `bin/mon-snapshot.sh <dir>` and `bin/mon-unitdiff.sh <old> <new>` for before/after comparisons.

---

## 1. Overview

### 1.1 Component diagram

```
                              ┌──────────────────────────── one host running the full stack ───────────────────────────┐
                              │                                                                                        │
  /var/log/*.log ─┐           │                                  ┌───────────────┐                                    │
  journald ───────┼─► Alloy ──┼──── push :3100 ───────────────►  │     Loki      │ ◄──── LogQL ───┐                   │
  maintenance     │  (lo:12345)│                                  │ (+ ruler)     │                │                   │
  .jsonl ─────────┘           │                                  └──────┬────────┘                │                   │
                              │                                         │ ruler alerts            │                   │
  node_exporter :9100 ─┐      │                                         ▼                         │                   │
  smartctl      :9633 ─┤      │                                  ┌───────────────┐          ┌─────┴──────┐            │
  blackbox      :9115 ─┼──────┼─ scrape ► ┌────────────┐ alerts► │ Alertmanager  │ webhook► │    ntfy    │ ► phone    │
  ntfy/loki/grafana/   ─┤     │           │ Prometheus │ ──────► │   :9093       │ :2586    │  topic     │            │
  alertmanager/alloy   ─┘     │           │   :9090    │         └───────────────┘ /alerts  │  "alerts"  │            │
  (/metrics)                  │           └─────┬──────┘                                   └────────────┘            │
  textfile: maintenance.prom ─┘                 │ datasource                                                          │
  textfile: backup_metrics.prom                 ▼                                                                     │
                              │          ┌───────────┐  datasources: Prometheus(uid prometheus, default),             │
                              │          │  Grafana  │  Loki(uid loki), Alertmanager(uid alertmanager)                │
                              │          │   :3101   │                                                                │
                              │          └───────────┘                                                                │
                              └────────────────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Components at a glance

| Component | Module registered as | Options namespace | systemd unit(s) | Role |
|---|---|---|---|---|
| Prometheus | `servc--prometheus-nixlab` | `services.prometheus-nixlab` | `prometheus`, `prometheus-permissions`, `prometheus-tsdb-guard` (+timer), `prometheus-wal-recover`, `backup-status-exporter` (opt.) | Scrapes, stores, evaluates alert + recording rules |
| Host exporters | `systm--host-exporters-nixlab` | `services.host-exporters-nixlab` | `prometheus-node-exporter`, `prometheus-smartctl-exporter` | Machine metrics (node, SMART) |
| Alertmanager | `servc--alertmanager-nixlab` (+ `nsops--alertmanager`) | `services.alertmanager-nixlab` | `alertmanager` (upstream module) | Group, route, inhibit, deliver |
| ntfy | `servc--ntfy-nixlab` | `services.ntfy-nixlab` | `ntfy`, `ntfy-permissions`, `ntfy-provision` | Push notification server |
| Loki | `servc--loki-nixlab` | `services.loki-nixlab` | `loki`, `loki-permissions`, `loki-wal-recover` | Log store + LogQL ruler |
| Alloy | `servc--alloy-nixlab` | `services.alloy-nixlab` | `alloy`, `alloy-permissions` | Ships journal, `/var/log/*.log`, maintenance log to Loki |
| Grafana | `servc--grafana-nixlab` (+ `nsops--grafana`) | `services.grafana-nixlab` | `grafana`, `grafana-permissions` | Dashboards; provisions datasources + dashboards |
| Maintenance log | `systm--maintenance-log-nixlab` | `services.maintenance-log-nixlab` | `maintenance-log-metrics` (+timer) | `maintenance-log` CLI, JSONL file, completion metrics |
| Observability backup | `systm--observability-backup-nixlab` | `services.observability-backup-nixlab` | `observability-backup` (+timer) | Nightly consistent copies of state |
| **Aggregator** | `stack--observability` | `services.nixlab-observability` | — | Wires all of the above together |

---

## 2. Design principles and why

1. **Atomic modules, one aggregator.** Grafana must know Prometheus and Loki exist; Prometheus must know where Alertmanager is; Alertmanager must know ntfy. If any service module knew its siblings, none could be reused or tested alone. So each `servc--*` module only declares its own options and exposes *escape hatches* (`extraScrapeConfigs`, `alertmanagerTargets`, `provisioning.datasources`, `receivers`, `route.routes`, `ruler.groups`, `extraConfig`), and the stack fills them. See the repo README's `stacks/` rules.
2. **Config as typed Nix, rendered at start.** Each service builds a Nix attrset, serialises to JSON, converts to YAML with `remarshal`, and installs it in `dataDir`. Reason: the data lives on a separate `/data` mount, configs must be inspectable on the host, and the same attrsets can be rendered and validated at *build time* in CI (`flake.lib.prometheusRendered`).
3. **Delegate where upstream is good, own the unit where it isn't.** Alertmanager, smartctl, blackbox and systemd exporters use the upstream NixOS modules (DynamicUser, amtool check, envsubst). Prometheus, Loki, Alloy, Grafana, ntfy and node_exporter are custom units so that paths, uids, hardening, ordering and self-healing are uniform.
4. **Loopback by default; expose explicitly.** Several hosts route over Wi-Fi, so exposure is by *named wired interface* (`access.interfaces`) not by blanket `openFirewall`.
5. **Observability must survive its own failure modes.** Prometheus can stay healthy (`/-/healthy` OK) while rejecting every sample, for example after a clock jump; rules that depend on stored metrics can't catch that. `absent_over_time`, a time-sync ordering, a TSDB guard, WAL self-heal, and an inhibit rule exist for this.
6. **Every alert is actionable and documented.** Alerts carry a checklist section, a runbook link and the exact condition that fired; CI refuses an alert with no runbook.
7. **Manual maintenance is data.** The "maintenance checklist" (31 sections) is mirrored in `checklist.nix`; completed tasks are logged as JSONL, shipped to Loki (2-year retention) and turned into last-completed metrics for the dashboard.
8. **Every host is self-contained.** No host scrapes, probes or ships logs to another by default; the same configuration runs everywhere and differences come from hardware and per-host overrides.
9. **Reproducible, verifiable deploys.** Pinned uids, ordered units, CI checks, and `bin/mon-*` scripts that compare before/after state.
10. **Precedence is explicit.** Stack tunables are `lib.mkDefault`: override with `services.nixlab-observability.*` *or* directly on `services.<x>-nixlab.*`. Wiring (datasources, scrape jobs, receivers, targets) is plain and additive: extend, don't replace.

---

## 3. Hosts and default configuration

Every host runs its own Prometheus, Alertmanager, ntfy, Loki, Alloy and Grafana. `hosts--profl--base` imports `stack--observability` and enables it on every host; hosts differ only in hardware and per-host overrides.

**Host facts that affect observability**

| Host | Address | nixpkgs | Battery | Drives | ZFS |
|---|---|---|---|---|---|
| nixnas1 | 10.0.0.251 | stable | none | NVMe + SAS/SCSI | pool `tanks` |
| nixnas2 | 10.0.0.252 | stable | none | ATA | no |
| nixace | 10.0.0.200 | unstable | BAT0 | NVMe + ATA | no |
| nixsun | 10.0.0.201 | unstable | BAT0 | ATA | no |
| nixtop | 10.0.0.202 | unstable | BAT0 | ATA | no |
| nixvat | 10.0.0.203 | unstable | none (Logitech `hidpp_battery_0` only) | ATA | no |
| nixzen | 10.0.0.204 | unstable | BAT0 | ATA | no |

Common: gateway 10.0.0.1, /24, DNS 9.9.9.9 + 1.1.1.1. `nvidia-smi` segfaults on the five GPU hosts, so there is no GPU exporter. Most hosts have both a wired and a Wi-Fi interface and several route through Wi-Fi, which is why exposure is by named wired interface.

**Consequences baked into the code**
- SAS/SCSI drives (nixnas1) expose `smartctl_scsi_*` rather than ATA attributes, hence the separate SCSI alert rules.
- Battery, ZFS, NVMe and fan alerts match nothing on hosts without those sensors; they simply never fire.
- The `zfs-monitoring` dashboard is opt-in (`extraDashboards`), used on nixnas1.
- CI validates one host per nixpkgs channel: `nixnas1` (stable) and `nixsun` (unstable).
- Laptops sleep; since each host only watches itself, nothing alerts about *another* host being off.

**Default configuration (`hosts--profl--base`)**
```nix
services.timesyncd.enable = true;
systemd.additionalUpstreamSystemUnits = ["systemd-time-wait-sync.service"];
systemd.services.systemd-time-wait-sync = {
  wantedBy = ["time-sync.target"];
  serviceConfig.TimeoutStartSec = "60s";      # offline laptops don't wait forever
};
services.nixlab-observability = {
  enable = true;
  openFirewall = false;
  dataDir = "/data";
  access.expose = ["grafana" "ntfy" "prometheus"];   # access.interfaces is empty
  notifications.ntfyAuth.enable = true;
  loki = { maintenance.enable = true; retention = "168h"; };
  prometheus = {
    maintenance.enable = true;
    maintenance.exporters.smartctl.enable = true;
    scrapeInterval = "60s"; retention = "7d"; retentionSize = "4GB";
  };
};
```
Two things follow from it (see §16): the values are plain assignments, so a host that sets the same option gets a conflicting-definition error unless it uses `lib.mkForce`; and with no `access.interfaces`, nothing is reachable from another machine.

---

## 4. File map

```
stacks/observability.nix                                  stack--observability (aggregator)
modules/ports.nix                                      systm--ports-{ntfy,loki,grafana,prometheus,alertmanager}
modules/nixos/observability/
├── alertmanager/default.nix                           servc--alertmanager-nixlab
├── alloy/default.nix                                  servc--alloy-nixlab
├── grafana/default.nix                                servc--grafana-nixlab, flake.lib.grafanaDashboards
├── grafana/dashboards/{maintenance-checklist,system-overview-v5,zfs-monitoring}.json
├── host-exporters/default.nix                         systm--host-exporters-nixlab
├── loki/default.nix                                   servc--loki-nixlab
├── maintenance-log/default.nix                        systm--maintenance-log-nixlab, flake.lib.maintenanceLoggerScript
├── maintenance-log/maintenance-logger.sh              the `maintenance-log` CLI
├── maintenance-log/_internals/checklist.nix           31 sections: code, name, hint
├── observability-backup/default.nix                      systm--observability-backup-nixlab
├── ntfy/default.nix                                   servc--ntfy-nixlab
└── prometheus/
    ├── default.nix                                    servc--prometheus-nixlab, flake.lib.prometheusRendered, flake.lib.prometheusMaintenanceAlerts
    └── _internals/
        ├── options.nix                                all options (incl. maintenance.*)
        ├── config.nix                                 users, dirs, services, tsdb-guard, bridge to host-exporters
        ├── services/prometheus.nix                    the prometheus systemd unit + preStart
        ├── rendered.nix                               prometheusConfig + rules attrsets (shared with CI)
        ├── scrape-configs.nix                         base / maintenance / extra scrape jobs
        ├── maintenance-alerts.nix                     all alert + recording rules, feature-gated
        ├── exporters/maintenance.nix                  blackbox, systemd exporter, backup-status exporter
        └── extras/nginx.nix                           optional nginx vhost
sops/alertmanager.nix  (+ alertmanager.env)            nsops--alertmanager
sops/grafana.nix       (+ grafana.yaml)                nsops--grafana
flake/nixos-lib.nix                                    nixlabLib helpers (hardening, WAL self-heal, permissions…)
flake/ci/observability-checks.nix                         build-time validation
flake/ci/_tests/prometheus/rules.test.yml              promtool rule unit tests
bin/mon-check.sh | mon-snapshot.sh | mon-unitdiff.sh   runtime verification
docs/runbooks/<Alert>.md, _template.md, _todo.txt      per-alert runbooks
docs/observability/observability.md
docs/secrets-rotation.md  docs/design-review.md
```

**Underscore convention.** Paths containing a `_`-prefixed segment (`_internals/`, `_tests/`) are *not* auto-imported by import-tree. They are plain files imported by relative path from their owner (`default.nix`) or referenced by CI. That is why `maintenance-alerts.nix` is both `import`ed by `rendered.nix` and registered as `flake.lib.prometheusMaintenanceAlerts` by `prometheus/default.nix`.

**`flake.lib` registrations made from `modules/`** (consumed by name, never by path): `serviceRegistry` (from the homepage module; the stack reads it), and for CI `grafanaDashboards` (the dashboards directory), `maintenanceLoggerScript`, `prometheusRendered` (function `{config, lib}` → `{rules, prometheusConfig}`), `prometheusMaintenanceAlerts` (function → `{groups, core, maintenance, allGroups}`).

---

## 5. The aggregator: `stack--observability`

`stacks/observability.nix`. Imports: `nsops--alertmanager`, `nsops--grafana`, `servc--{alloy,loki,prometheus,ntfy}-nixlab`, `systm--maintenance-log-nixlab`, `systm--observability-backup-nixlab` (Prometheus itself imports `systm--host-exporters-nixlab`). Takes `hostMeta` (from `mkHost`'s specialArgs; defaults to `{}`) for `address` and `gateway`. Reads `self.lib.hostsMeta` for `probes.hosts` addresses and `self.lib.serviceRegistry` *(not in provided code)* for local service ports.

### 5.1 Options: `services.nixlab-observability`

| Option | Default | Meaning |
|---|---|---|
| `enable` | false | Turns on the whole stack |
| `listenAddress` | null | Force one bind address for *all* services (overrides per-service logic; loopback scrape jobs then may not reach them) |
| `publicHost` | `hostMeta.address` | Host/address used in UI links and notification links; builds each service's `externalUrl` |
| `access.interfaces` | `[]` | Wired interfaces on which `access.expose` ports are opened (never Wi-Fi). Empty → loopback only |
| `access.expose` | `[grafana ntfy prometheus]` | Subset of `grafana ntfy alertmanager prometheus loki` |
| `probes.gateway` | `hostMeta.gateway` | ICMP-probed |
| `probes.hosts` | `[]` | Other hosts (names in `hostsMeta`) to ICMP-probe; this host's own address is filtered out |
| `probes.tcpFromRegistry` | true | TCP-probe loopback ports of services enabled on this host |
| `openFirewall` | false | Legacy: open each service port on all interfaces |
| `dataDir` | `/data` | Root; each service uses `<dataDir>/<svc>` |
| `loki.retention` / `loki.maintenance.enable` | `744h` / false | Log retention; maintenance logging (Alloy pipeline + helper) |
| `prometheus.maintenance.enable` | **false** (true via `hosts--profl--base`) | **Loads all non-core alert groups, smartctl/blackbox exporters, textfile dir** |
| `prometheus.scrapeInterval` | `30s` | Scrape and evaluation interval |
| `prometheus.retention` / `.retentionSize` | `15d` / null | TSDB retention; size cap (set on laptops) |
| `prometheus.maintenance.exporters.systemd` / `.smartctl.enable` | false / true | Separate systemd exporter (redundant with node's collector) / SMART exporter |
| `ntfy.cachePersist` | true | Persist ntfy cache to `<dataDir>/ntfy/cache.db` |
| `notifications.useNtfy` | true | Wire Alertmanager → ntfy; false means define your own receivers |
| `notifications.ntfyTopic` | `alerts` | Topic |
| `notifications.formatMessages` | true | ntfy templating (needs ntfy ≥ 2.10) |
| `notifications.ntfyAuth.enable` | false | ntfy auth, `alertmanager` (write-only) + `reader` (read-only) users |
| `notifications.separateCritical` | true | Critical alerts get their own receiver (priority 5) |
| `integrations.{traefik,cadvisor,postgres}.{enable,target}` | off; `127.0.0.1:8082/8080/9187` | Extra scrape job + feature-flag the matching alert groups |

### 5.2 Bind address and exposure logic

```
bindAddress(name) =
    listenAddress                                   if listenAddress != null
    "0.0.0.0"                                       if access.interfaces != [] && name ∈ access.expose
    "127.0.0.1"                                     otherwise
networking.firewall.interfaces.<iface>.allowedTCPPorts = [ port of each name ∈ access.expose ]   (for each iface in access.interfaces)
```
Ports 9094 (Alertmanager gossip) and Loki gRPC are never opened. Per-service `openFirewall` is set to `mkDefault cfg.openFirewall` (false), overriding each module's own default of `true`.

### 5.3 What the stack wires (the cross-service contract)

| Wiring | Where it lands |
|---|---|
| uids/gids (`mkDefault`) loki 740, alloy 741, grafana 742, prometheus 743, ntfy 744 | each module's `uid`/`gid` |
| `dataDir` = `<dataDir>/{grafana,loki,prometheus,ntfy}`; `listenAddress`; `openFirewall` | each module |
| `externalUrl` = `http://<publicHost>:<port>/` (ntfy without trailing slash) | grafana, alertmanager, prometheus, ntfy |
| Grafana `prometheusUrl` = Prometheus `externalUrl` or `http://localhost:9090` | dashboards' `prometheus_url` variable (browser-reachable link target) |
| Grafana datasources `Prometheus` (uid `prometheus`, default), `Loki` (uid `loki`), `Alertmanager` (uid `alertmanager`, `implementation=prometheus`, `handleGrafanaManagedAlerts=false`), all at `127.0.0.1` | `services.grafana-nixlab.provisioning.datasources` |
| Scrape jobs `ntfy`, `loki`, `grafana`, `alertmanager` (loopback), `alloy` (if enabled), plus traefik/cadvisor/postgres if enabled | `services.prometheus-nixlab.extraScrapeConfigs` |
| `alertmanagerTargets = [127.0.0.1:9093]` | Prometheus → Alertmanager |
| Alert feature flags `traefik`, `containers`, `postgres` | `maintenance.alerts.features` |
| ICMP targets: gateway + `probes.hosts` (minus self); TCP targets from the service registry | `maintenance.exporters.blackbox.{icmpTargets,tcpTargets}` |
| Receivers `null`, `ntfy`, (`ntfy-critical`); default receiver `ntfy` | Alertmanager |
| Route: `severity="critical"` → `ntfy-critical` (groupWait 10s, repeat 1h); everything else → `ntfy` | Alertmanager |
| Loki ruler enabled, `alertmanagerUrl=http://127.0.0.1:9093`, rule group `journal` (4 alerts) | Loki |
| Alloy enabled from Loki's `enableAlloy`; `port`, `package` from Loki's `alloyPort`, `alloyPackage`; `lokiUrl` local; maintenance pipeline appended to Alloy config when `loki.maintenance.enable` | Alloy |
| `maintenance-log-nixlab.{enable,logPath}` follow Loki's `maintenance.*`; `textfileDir=/var/lib/node_exporter` when Prometheus maintenance is on | helper |
| ntfy auth users + `environmentFile = ALERTMANAGER_ENV` secret path; a changed secret restarts `ntfy-provision` | ntfy (when `ntfyAuth.enable`) |
| Backup sources: sqlite `grafana.db`, ntfy `cache.db`, ntfy `user.db` (if auth); plain `/var/lib/private/alertmanager` and the maintenance log; target `<dataDir>/backup` | `observability-backup-nixlab` |

### 5.4 ntfy notification format

Alertmanager posts its webhook JSON to `http://127.0.0.1:2586/<topic>?...`. With `formatMessages`, ntfy renders it with a Go template (`tpl=1`):
- **Title:** `[<status>] <host>: <alertname>` — `host` is the *first alert's* `host` label (Prometheus external label, or the aggregation label on Loki-ruler alerts).
- **Message:** for each alert: summary, description, runbook URL (if present).
- **Priority/tags:** `ntfy` tags=`warning`; `ntfy-critical` p=5 tags=`rotating_light`.
- **Click:** opens Grafana (`click=` set when Grafana has an `externalUrl`).
- Basic auth to ntfy (`alertmanager` / `$NTFY_ALERTMANAGER_PASSWORD`) when `ntfyAuth.enable`.

---

## 6. Component reference

Conventions: **Unit** = systemd unit; **State** = on-disk state; **Hardening** = flags passed to `mkServiceHardening` (§11).

### 6.1 Prometheus (`servc--prometheus-nixlab`)

**Files:** `default.nix` (entry: imports `systm--ports-prometheus` and `systm--host-exporters-nixlab`; wraps config in `mkIf enable (mkMerge [config.nix, mkWalSelfHeal])`), `_internals/*`.

**Unit `prometheus`** (`services/prometheus.nix`): custom unit, user/group `prometheus`, `after network.target prometheus-permissions.service time-sync.target`, `wants time-sync.target`. Hardening: `extraHardening`, `writablePaths=[dataDir]`. `Restart=on-failure`, `RestartSec=10s`, `ExecReload` = SIGHUP.
`preStart` (runs as `prometheus`): renders `prometheus.yml` (mode 660) and `rules/alerts.yml` (mode 644) from JSON via `remarshal`, `mkdir data`.
`ExecStart`: `--config.file=<dataDir>/prometheus.yml --storage.tsdb.path=<dataDir>/data --storage.tsdb.retention.time=<retention>[ --storage.tsdb.retention.size=…] --web.listen-address=<addr>:<port>[ --web.external-url=…]`.

**Users:** `prometheus` (system user, `uid/gid` from options, extra group `disk` if smartctl is on) and every `mainUser`/`extraUsers` is added to group `prometheus` (read access to data).

**Rendered config** (`rendered.nix`, also used by CI):
- `global`: `scrape_interval`, `evaluation_interval` (module defaults 15s; stack sets 30s), `external_labels = {monitor="prometheus", host=<hostname>}`. The `host` external label is attached to every alert sent to Alertmanager and is what notifications show.
- `alerting.alertmanagers`: one static config when `alertmanagerTargets != []`.
- `rule_files: ["<dataDir>/rules/*.yml"]`.
- `scrape_configs` (see below).
- Rules: `core` groups ++ (if `maintenance.enable`) `maintenance` groups. Rendered with `runbookBase = https://github.com/Temhr/nixlab/blob/main/docs/runbooks` and the `condition` label on.

**Scrape jobs** (`scrape-configs.nix`)

| Job | Target | Condition | Notes |
|---|---|---|---|
| `prometheus` | `localhost:<port>` | always | |
| `node` | `localhost:9100` | `enableNodeExporter` | labels `instance="localhost"`, `alias=<hostname>` |
| `systemd` | `localhost:9558` | maintenance + `exporters.systemd` | off by default |
| `smartctl` | `localhost:9633` | maintenance + `smartctl.enable` | `slowScrapeInterval` (60s) |
| `blackbox-http` / `-icmp` / `-ssl` / `-dns` / `-tcp` / `-http-insecure` | per target list | maintenance + blackbox enabled + non-empty list | blackbox pattern: `__address__`→`__param_target`→`instance`, address rewritten to `localhost:9115`, modules `http_2xx`, `icmp`, `http_2xx` (ssl), `dns_a`, `tcp_connect`, `http_2xx_insecure` |
| extras | — | from `extraScrapeConfigs` | stack: ntfy, loki, grafana, alertmanager, alloy, integrations |

**Exporters** (`exporters/maintenance.nix`): upstream `services.prometheus.exporters.systemd` and `.blackbox` (listen `127.0.0.1` via `mkDefault`; blackbox modules file written to the store: `http_2xx`, `http_2xx_insecure`, `dns_a` using `dnsQueryName`, `icmp`, `tcp_connect`, all `preferred_ip_protocol: ip4`, 5s timeouts). Optional `backup-status-exporter` unit (loop every 300s reading a timestamp file and a size file and writing `/var/lib/node_exporter/backup_metrics.prom`: `backup_job_last_success_timestamp`, `backup_job_size_bytes`, label `job_name`). Off by default.

**Bridge to host-exporters:** `config.nix` sets `services.host-exporters-nixlab.{nodeExporter.enable, nodeExporter.textfileDir, smartctl.enable/port/devices}` from Prometheus options, using `mkDefault` so a host can override. Also creates `/var/lib/node_exporter` (0755 prometheus) when maintenance is on.

**Other units** (`config.nix`): `prometheus-permissions` (§11), `prometheus-tsdb-guard` + timer (§12), and `prometheus-wal-recover` (via `mkWalSelfHeal`, `walDir=<dataDir>/data/wal`).

**Options** (`services.prometheus-nixlab`): `enable`, `port` (9090), `listenAddress` (127.0.0.1), `domain`, `externalUrl`, `enableSSL`, `dataDir` (default `/var/lib/prometheus2`; stack: `/data/prometheus`), `retention` (15d), `retentionSize`, `scrapeInterval`, `evaluationInterval`, `slowScrapeInterval`, `package`, `openFirewall`, `blackboxPort`, `smartctlPort`, `systemdExporterPort`, `enableNodeExporter`, `uid`, `gid`, `extraScrapeConfigs`, `alertmanagerTargets`, `extraUsers`, and `maintenance.{enable, expectedMounts, alerts.features.{traefik,containers,postgres}, exporters.{systemd, blackbox.{enable,httpTargets,icmpTargets,sslTargets,dnsTargets,tcpTargets,httpInsecureTargets,dnsQueryName}, smartctl.{enable,devices}, backup.{enable,timestampFile,sizeFile,jobName}}}`.

**Derived alert feature flags** (`rendered.nix`): `backup` = backup exporter enabled; `dns` = blackbox on and `dnsTargets != []`; `blackboxProbes` = blackbox on and any of http/icmp/ssl/tcp/http-insecure targets non-empty; `alertmanagerWired` = `alertmanagerTargets != []`; plus the three user flags.

### 6.2 Host exporters (`systm--host-exporters-nixlab`)

Node and smartctl exporters live in their own module so they can run without Prometheus.

- **Node exporter** (`prometheus-node-exporter`, custom unit, runs as `cfg.user`, default `prometheus`; the user/group are `mkDefault`ed here so Prometheus' own definition wins when it is enabled). Listen `localhost:9100` by default. Collectors enabled: `pressure`, `processes`, `systemd` (+ restart metrics; only `.service`/`.timer` units), `hwmon`, `netclass`, `netdev`, and `textfile` when `textfileDir` is set. Filesystem collector excludes mountpoints `/dev|/proc|/run|/sys` and fs types incl. `nfs`, `nfs4`, `overlay`, `squashfs`, `tmpfs`-like pseudo types (NFS client mounts are not checked). ZFS metrics (`node_zfs_*`, `node_zfs_zpool_state`) come from node_exporter's default zfs collector.
  Hardening: `extraHardening` but with `SystemCallFilter=""`, `ProtectClock=false` (the timex collector needs `adjtimex`; otherwise `ClockDrift` goes silent), `ProtectProc=default`, `ProcSubset=all`, `RestrictAddressFamilies` incl. `AF_NETLINK`, `MemoryMax=256M`, `TasksMax=128`.
- **smartctl exporter**: upstream module on `127.0.0.1:9633`; the unit is given `CAP_SYS_RAWIO` (ambient + bounding), `DeviceAllow` for `/dev/sd*` and `/dev/nvme*` (read), `PrivateDevices=false`. `devices=[]` means scan.

### 6.3 Alertmanager (`servc--alertmanager-nixlab`)

Delegates to upstream `services.prometheus.alertmanager` (DynamicUser, state under `/var/lib/private/alertmanager`, amtool config check, envsubst of `$VAR`). The module assembles `configuration` from typed options and deep-merges `extraConfig` over it (`recursiveUpdate`; lists such as `receivers` are replaced, not merged).

- **Config shape:** `global.resolve_timeout` (5m) + optional SMTP/Slack/PagerDuty globals; root `route` (`receiver=defaultReceiver`, `group_by=[alertname instance]`, `group_wait 30s`, `group_interval 5m`, `repeat_interval 4h`) with child `routes`; `receivers`; `inhibit_rules`; `time_intervals`.
- **Default inhibit rules:**
  1. `severity=critical` suppresses `severity=warning` when `instance` and `category` are equal. (Consequence: a critical on one mountpoint suppresses warnings for other mountpoints on that host.)
  2. `alertname=PrometheusNoRecentSamples` suppresses `category=observability` alerts (except itself) for the same `instance` — when Prometheus can't store samples, its other self-reports are unreliable.
- **Secrets:** `environmentFile` (set by `nsops--alertmanager`) is passed to the upstream module; `$VAR` references in receivers are expanded at start. `checkConfig` defaults to `environmentFile == null` (build-time `amtool` can't see secrets); an assertion forbids env file + `checkConfig=true`.
- **Clustering:** with no `clusterPeers`, `--cluster.listen-address=` (empty) disables the gossip listener (previously `*:9094`). With peers, it listens on `clusterPort` and an assertion requires `openFirewall`.
- **`webExternalUrl`:** `domain` → `externalUrl` → `http://<listen>:<port>/`. The upstream module appends the port to `listenAddress`; never include it.
- **Assertions:** SSL needs domain; every route/default receiver name must exist in `receivers`; env-file/checkConfig; cluster peers need firewall.
- **Options:** `enable, port, listenAddress, domain, externalUrl, enableSSL, package, openFirewall, checkConfig, environmentFile, clusterPeers, clusterPort, global.*, defaultReceiver, route.{groupBy,groupWait,groupInterval,repeatInterval,routes}, receivers, inhibitRules, timeIntervals, extraConfig`. Route submodule: `receiver, matchers, groupBy, groupWait, groupInterval, repeatInterval, continue, muteTimeIntervals`.

### 6.4 ntfy (`servc--ntfy-nixlab`)

Custom unit `ntfy` (user/group `ntfy`, `extraHardening`). `preStart` renders `server.yml` (mode 640) from an attrset.

- **Generated config:** `base-url` (domain → `externalUrl` → listen address), `listen-http`, `cache-duration` (12h), `cache-file` if set, topic/visitor limits, `enable-signup=false`, `enable-login`/`enable-reservations` = `auth.enable`, `enable-metrics=true`, `behind-proxy` = domain set, attachment settings (opt.), `auth-file=<dataDir>/user.db` + `auth-default-access` when auth is on, SMTP-to-ntfy bridge (opt.), `upstream-base-url` (opt.), `web-root=disable` if `enableWebUI=false`.
- **Auth provisioning** (`ntfy-provision`, oneshot, `RemainAfterExit`): waits (≤30s) for `/v1/health`, then for each user in `auth.users`: `ntfy user add --ignore-exists --role=…`, `ntfy user change-pass`, `ntfy access <user> <topic> <perm>`. Passwords come from `auth.environmentFile` via variable names (`passwordEnvVar`); the CLI reads `NTFY_PASSWORD`. Idempotent. Stack users: `alertmanager` (write-only on topic) and `reader` (read-only).
- **Assertions:** SSL needs domain; `auth.users` needs `auth.enable` and an env file; SMTP needs a domain; attachments need `cacheFile`.
- **Firebase** key via `Environment=NTFY_FIREBASE_KEY_FILE=…` (opt.).

### 6.5 Loki (`servc--loki-nixlab`)

Custom unit `loki` (user/group `loki`, `extraHardening`, `TimeoutStopSec=5min` so WAL flush on stop isn't killed). Imports `systm--ports-loki`. Config rendered in `preStart` to `<dataDir>/loki.yaml`.

- **Generated config:** single-binary, `auth_enabled=false`, in-memory ring, replication 1; HTTP on `listenAddress:port`; **gRPC bound to `127.0.0.1:9096`**; filesystem chunk store; TSDB index schema `v13` from 2023-01-01 (period 24h); WAL enabled at `<dataDir>/wal`, `flush_on_shutdown`; compactor with retention enabled (delete delay 2h); 100 MB embedded results cache.
- **Limits:** retention `retention` (default 744h = 31d); stream override **`{job="maintenance-log"}` kept 17520h (2 years)**, priority 1; ingestion 4 MB/s (burst 8), per-stream 3 MB/s (burst 10); `reject_old_samples` older than 168h; `max_entries_limit_per_query` 5000; `max_query_series` 10000.
- **Ruler** (opt.): local rule storage `<dataDir>/rules/fake/journal.yaml` (`fake` is the tenant name when auth is off), `alertmanager_url`, API enabled. Rule groups come from `ruler.groups` (set by the stack).
- **Self-heal:** `mkWalSelfHeal` on `<dataDir>/wal`. `loki-permissions` oneshot re-chowns the data dir at boot.
- **Options read by the stack, not by Loki:** `enableAlloy`, `alloyPackage`, `alloyPort`, `maintenance.{enable,logPath}` — Loki does not run Alloy; the *stack* reads these to configure `services.alloy-nixlab` and `maintenance-log-nixlab` (see `docs/design-review.md`). `grpcPort`, `openGrpcFirewall` (default false; multi-instance only).
- **Assertions:** SSL needs domain; maintenance log path must not end in `.log` (it would be ingested twice by the `/var/log/*.log` pipeline); ruler needs `alertmanagerUrl`.

### 6.6 Alloy (`servc--alloy-nixlab`)

Custom unit `alloy` (user/group `alloy`, member of `systemd-journal`; `allowJIT`, `extraHardening`, with `/proc` fully visible). Runs `alloy run --disable-reporting --server.http.listen-addr=127.0.0.1:<port> --storage.path=/var/lib/alloy/data /var/lib/alloy/config.alloy`. `preStart` installs the generated config.

- **Base pipelines** (host label = hostname):
  - `loki.write "local"` → `lokiUrl`.
  - Journal: `loki.source.journal "systemd"` (`max_age 12h`), relabel `__journal__systemd_unit`→`unit`, `__journal_priority_keyword`→`level`, `__journal__transport`→`transport`; processed with static labels `job=systemd-journal`, `host`, keeping only `job host unit level transport`.
  - Files: `/var/log/*.log` → `job=varlogs`, `host`.
- **Appended `extraConfig`:** the stack adds the maintenance pipeline when `loki.maintenance.enable`: tail `maintenance.logPath`, parse JSON, labels `section status user`, static `job=maintenance-log host=<hostname>`, timestamp from the entry's `timestamp` (RFC3339).
- **Ordering:** after `network.target`, local `loki.service` (if `afterLocalLoki`, default true), `alloy-permissions.service`, `time-sync.target`.
- `lokiUrl` can point at a Loki elsewhere; set `afterLocalLoki=false` if no Loki runs on the host.

### 6.7 Grafana (`servc--grafana-nixlab`)

Custom unit `grafana` (user/group `grafana`, `extraHardening`, `UMask=0027`). Configured entirely by `GF_*` environment variables (paths under `<dataDir>`: `data`, `logs`, `plugins`, `provisioning`, `dashboards`; sqlite DB `data/grafana.db`; analytics, sign-up, Gravatar, news feed all off; anonymous access off unless `allowAnonymous`).

- **Secrets:** `GF_SECURITY_ADMIN_PASSWORD__FILE` / `GF_SECURITY_SECRET_KEY__FILE` from `credentialsFile` / `secretKeyFile` (plain strings, never `path`, so nothing enters the store). A warning is emitted if `secretKeyFile` is null. The admin password applies only on first DB creation; afterwards use `grafana cli admin reset-admin-password`. Changing the secret key on an existing DB makes stored secrets unreadable.
- **`ExecStartPre` step 1 (root, `+` prefix):** removes dashboard dirs and provisioning YAMLs that are no longer declared; backs up `grafana.db` once per day (`grafana.db.pre-cleanup-<date>`); deletes from the sqlite DB any *provisioned* dashboard that is no longer declared or whose uid no longer matches the JSON file (so renamed/re-uid'd dashboards re-provision cleanly), and empty folders; creates the provisioning/dashboard directories.
- **Step 2 (grafana user):** writes `provisioning/datasources/datasources.yaml` (from `provisioning.datasources`, type lower-cased); for each dashboard, copies the JSON to `dashboards/<name>/dashboard.json` via `jq`, rewriting the `prometheus_url` template variable to `prometheusUrl`; writes a file-provider YAML (`folder`, `updateIntervalSeconds`, `allowUiUpdates`).
- **Dashboards:** `dashboards` (default: `maintenance` → `maintenance-checklist.json`, `system-overview-v5` → `system-overview-v5.json`), plus `extraDashboards` (list of names resolving to `dashboards/<name>.json`, folder `maintenance`). Assertions: all named files exist; no name clashes with built-ins. After adding a JSON file, `git add` it.

| Dashboard | uid | Contents |
|---|---|---|
| `maintenance-checklist.json` | `maintenance-checklist` | Health score gauge, active alerts by severity, resource overview; for each checklist section I–VI an *automated* table (`ALERTS{checklist_section=~"I\\..*"}`) beside a *manual tasks* markdown panel; cert expiry timeline; uptime matrix; weekly/monthly/quarterly summaries; alert history |
| `system-overview-v5.json` | `system-maintenance-overview-v5` | Health score, alerts by severity, failed units, hottest sensor, uptime, kernel, root FS, RAM, swap; firing/pending alert table with `condition` and Prometheus deep-link; firing by category/section; CPU, memory, pressure, disk, inode, IO, time-to-full, network, hwmon temperatures, CPU frequency, clock offset, failed units; service uptime; alert timeline; collapsed rows: **Observability Stack Health**, **Containers**, **Web & Network Probes**, **Backups & Certificates**, **Maintenance Checklists**; Extended metrics; Drive health (SMART, temperature, NVMe wear); Timers; Logs (Loki: journal errors by unit, failed SSH logins, kernel warnings); Maintenance (days since last completed, failed/skipped entries, recent entries) |
| `zfs-monitoring.json` (opt-in: `extraDashboards=["zfs-monitoring"]`) | `zfs-pool-monitoring` | Pool state, dataset I/O, ARC, ZIL, dataset space; `$zpool` variable |

Dashboards use the hidden datasource variable `DS_PROMETHEUS` (resolves to the default Prometheus datasource) and the fixed Loki uid `loki`. Dashboard-only metrics that need other exporters (containers, traefik, backups) show "no … metrics" placeholders until enabled.

### 6.8 Maintenance log (`systm--maintenance-log-nixlab`)

- **Checklist** (`_internals/checklist.nix`): 31 entries `{code, name, hint}` — I.1–I.3 hardware, II.4–II.6 OS, III.7–III.9 storage/backup, IV.10–IV.13 network/security, V.14–V.17 services, VI.18–VI.20 containers/VMs, VII.21–VII.23 observability itself, VIII.24–VIII.26 config/docs, IX.27–IX.28 redundancy/DR, X.29–X.31 weekly/monthly/quarterly. There is no cadence or overdue tracking. This list is also the source of truth for the `checklist_section` labels used on alerts.
- **CLI** `maintenance-log` (wrapper over `maintenance-logger.sh`, with `jq coreutils gawk gnugrep` on PATH, `MAINTENANCE_LOG`, `MAINTENANCE_CHECKLIST` set). Interactive menu or flags:
  ```
  maintenance-log --section X.30 --task "Applied updates" [--status completed|skipped|failed] [--notes "…"] [--when "3 days ago"]
  maintenance-log --list-sections | --help
  ```
  `QUICK` is a valid free-form section. Entries are JSON lines `{timestamp(UTC), level, section, task, status, notes, hostname, user}`; under `sudo`, `user` is the invoking user.
- **File:** `/var/log/maintenance.jsonl` (never `.log`), mode 0664 `root:wheel` (wheel-writable only, to prevent forged audit entries), logrotate monthly, 24 kept, `copytruncate`.
- **Metrics** (only if `textfileDir` set): timer every 5 min (+1 min after boot) runs `maintenance-log-metrics`, which reads the current file and `.1`, finds the latest `completed` timestamp per section, and writes `<textfileDir>/maintenance.prom` with `maintenance_last_completed_timestamp_seconds{section}` for **every** section (0 = never). The dashboard panel *Days since last completed, by section* uses it; there is no alert.

### 6.9 Observability backup (`systm--observability-backup-nixlab`)

Daily at 03:15 (+≤15 min, `Persistent`), `observability-backup` oneshot (root, `UMask 0077`): for each SQLite file, `sqlite3 <f> ".backup '<dir>/<basename>.bak'"` (consistent online copy); for each plain path, `cp -a` into `<dir>`. The stack points `dir` at `<dataDir>/backup`; **that directory must be included in your normal off-host backup** (`backup-home` sources). Prometheus TSDB and Loki chunks are *not* backed up.

---

## 7. Alerting reference

### 7.1 Pipeline

1. Prometheus evaluates rule groups (each group has its own `interval`, 30s–5m).
2. Deployed rules get (a) a `condition` label = the whitespace-squashed expr plus ` (for <dur>)`, so a firing alert shows *why* directly from the `ALERTS` series, and (b) a `runbook` annotation = `…/docs/runbooks/<alert>.md`. Neither is applied in unit tests/CI rule files (`conditionLabel=false`, `runbookBase=null`).
3. Firing alerts go to Alertmanager (`alertmanagerTargets`), carrying the `host` external label.
4. Alertmanager groups by `alertname, instance`, applies inhibition (§6.3), picks a route: critical → `ntfy-critical`; everything else (warnings) → `ntfy`.
5. The receiver webhooks ntfy; ntfy templates it (§5.4).
6. Loki-ruler alerts skip Prometheus and go straight Loki → Alertmanager.

### 7.2 Label conventions

| Label | Values | Use |
|---|---|---|
| `severity` | `warning`, `critical` | Routing, inhibition, health score (critical −20, warning −5, floor 0) |
| `category` | `hardware storage os network security service web database container backup observability` | Inhibition (`equal`), dashboards |
| `checklist_section` | e.g. `I.1`, `VII.21` | Maps to the maintenance checklist; dashboard tables filter on it |
| `condition` | generated | Why it fired |

### 7.3 Feature gating

Rules may carry `requires = "<flag>"`; they load only when the flag is true (and the attribute is stripped). Flags: `traefik`, `containers`, `postgres`, `backup`, `dns`, `blackboxProbes`, `alertmanagerWired`. Groups marked `core = true` load even when `maintenance.enable=false`: `observability_stack`, `stack_self_health`, `maintenance_metrics`. `ExpectedMountMissing` is generated once per entry in `maintenance.expectedMounts` (host option, not exposed by the stack).

### 7.4 Alert catalogue (Prometheus)

Section = `checklist_section`. **W** warning, **C** critical. "for" is the pending time.

**hardware_health (30s)**
| Alert | Sev | Condition (summary) | for |
|---|---|---|---|
| HighCPUTemperature | W | coretemp/k10temp/amdgpu hwmon >80 and ≤90 °C (I.1) | 5m |
| CriticalCPUTemperature | C | same sensors >90 °C | 2m |
| NVMeHighTemperature | W | `nvme` hwmon >75 and ≤85 °C | 10m |
| NVMeCriticalTemperature | C | `nvme` >85 °C | 5m |
| CPUThrottling | W | cores below 60% of max freq while >50% busy, not on battery (aggregated per host) | 10m |
| FanSpeedLow | W | fan <1000 rpm that was >1500 in 7d, while host >55 °C | 5m |
| LowDiskSpace | W | 10–20% free (I.2) | 5m |
| CriticalDiskSpace | C | <10% free | 2m |
| DiskWillFillIn24h | W | `predict_linear` 6h → <0 in 24h and <50% free | 1h |
| HighInodeUsage | W | <20% inodes free | 5m |
| NetworkInterfaceErrors | W | >10 errs/s (I.3) | 5m |
| NetworkPacketDrops | W | >50 drops/s | 5m |

Filesystem filter excludes `tmpfs overlay squashfs ramfs devtmpfs nsfs erofs fusectl fuse.* zfs` and `/nix/store`, `/run/*`; network filter excludes `lo veth docker br- virbr`.

**os_health (1m)** — OutOfMemoryKills (C, no `for`, II.5), ClockDrift (W, |offset|>0.1 s, 10m), ClockNotSynced (W, `node_timex_sync_status==0`, 15m), HighCPULoad (W, load5/core >1.5, 30m, II.6), HighMemoryUsage (W, >85%, 5m), SwapUsage (W, >50%, 5m), HighIOWait (W, avg iowait >30%, 10m).

**storage_backups (5m)** *(all gated `backup`)* — BackupJobFailed (C, age >24h, for 1h, III.7), BackupSizeAnomaly (W, ±30% vs 7d ago), BackupMetricsMissing (W, `absent(...)`).

**network_security (1m)** — DNSResolutionFailure (C, gated `dns`, 3m, IV.12), HighNetworkLatency (W, ICMP >100 ms, 5m), CertificateExpiringSoon (W, 7–30 d, 1h, IV.13), CertificateExpiringCritical (C, <7 d, 1h).

**service_health (30s)** — HostDown (W, own node exporter down while Prometheus is up, 5m, V.14), ServiceDown (C, `up{job!~"prometheus|node"}==0`, 2m), SystemdServiceFailed (W, 5m), PostgresReplicationLag (W, gated `postgres`, V.15), HighHTTPErrorRate (W, gated `traefik`, 5xx ratio >5% and >0.05 req/s, 5m, V.16).

**container_health (30s)** *(gated `containers`)* — ContainerRestartLoop (W, >2 start-time changes in 15m, VI.18), ContainerHighMemory (W, >90% of a non-zero limit).

**probes (1m)** *(gated `blackboxProbes`)* — ProbeFailed (W, http/http-insecure/icmp/tcp probe_success==0, 5m, IV.12), SSLProbeFailed (W, 10m, IV.13).

**observability_stack (core, 1m)** — PrometheusNoRecentSamples (C, `absent_over_time(up{job="prometheus"}[10m])`, 5m, VII.21), PrometheusSamplesOutOfBounds (C, 10m), PrometheusHeadInFuture (C, head >1h ahead, 5m), PrometheusRuleEvaluationFailures (W, VII.22).

**stack_self_health (core, 1m)** — PrometheusConfigReloadFailed (C, 5m, VII.21), PrometheusNoAlertmanager (C, gated `alertmanagerWired`, 10m, VII.22), PrometheusNotificationsFailing (C, 10m), AlertmanagerNotifyFailing (C, 10m), PrometheusWALCorruption (W, no `for`), PrometheusCompactionFailing (W), LokiDiscardingSamples (W, 10m, VII.23), AlloyDroppingEntries (W, 10m).

**smart_health (5m)** — SMARTStatusFailed (C, I.1), SMARTErrorLogGrowing (W), SMARTSectorsGrowing (W; Reallocated/Pending/Offline_Uncorrectable growth in 7d), NVMeWearHigh (W, >80%), NVMeCriticalWarning (C), NVMeMediaErrors (W), NVMeSpareLow (C), SCSIDefectsGrowing (W, SAS grown defect list), SCSIUncorrectedErrors (W). The SCSI pair exists because SAS drives (nixnas1) expose `smartctl_scsi_*` instead of ATA attributes.

**filesystem_integrity (1m)** — FilesystemReadOnly (C, 2m), FilesystemDeviceError (W, 5m), ExpectedMountMissing (C, 5m, one per expected mount).
**zfs_health (1m)** — ZpoolNotOnline (C, III.8, 2m), ZpoolLowFree (W, <15% free, 15m).
**battery_health (5m)** — BatteryHealthDegraded (W, <60% of design capacity, 1h; supports `energy_*` and `charge_*` metrics).
**Recording rules** (`maintenance_metrics`, core): `system:health_score:percentage`, `system:alerts_by_category:count`, `system:alerts_by_section:count`, `node:disk_usage:percentage`, `node:memory_usage:percentage`, `node:cpu_usage:percentage`. They read `ALERTS`, so they only reflect Prometheus-evaluated alerts.

### 7.5 Loki-ruler alerts (defined in the stack, group `journal`, 1m)

| Alert | Sev | LogQL (kernel/journal, 5m window unless noted) | Section |
|---|---|---|---|
| JournalOOMKill | C | kernel "out of memory: kill\|oom-kill" | II.5 |
| KernelFilesystemError | C | EXT4/XFS/BTRFS errors, "Remounting … read-only", "I/O error, dev" | III.8 |
| NvidiaXid | W | kernel `NVRM: Xid` | I.1 |
| SSHAuthFailureBurst | W | sshd failures >20 in 10m | IV.10 |

They set `instance={{ $labels.host }}`, `severity`, `category`, `checklist_section` so routing and inhibition work. They **do not exist as `ALERTS` series**: not in dashboard alert tables, the health score, `runbook-coverage`, or the promtool tests.

### 7.6 Runbooks

`docs/runbooks/<AlertName>.md` using `_template.md` (What it means / Likely causes / First three commands / Fix / Escalate when / Related). `_todo.txt` lists alert names whose runbook is still to be written; delete a line when you write the page. The `runbook-coverage` check fails if an alert has neither.

---

## 8. Data flows

| Flow | Path |
|---|---|
| **Host metrics** | node_exporter `:9100` + textfile dir (`maintenance.prom`, `backup_metrics.prom`) → Prometheus job `node` |
| **SMART** | smartctl_exporter `:9633` → job `smartctl` (60s) |
| **Probes** | Prometheus → blackbox `:9115` `/probe?module=…&target=…` → jobs `blackbox-*` |
| **Stack self-metrics** | Prometheus scrapes its own `/metrics`, plus ntfy, loki, grafana, alertmanager, alloy |
| **Logs** | journald / `/var/log/*.log` / maintenance JSONL → Alloy → Loki push API (`/loki/api/v1/push`) |
| **Metric alerts** | Prometheus rules → Alertmanager `/api/v2/alerts` → webhook → ntfy |
| **Log alerts** | Loki ruler → Alertmanager → webhook → ntfy |
| **Manual maintenance** | `maintenance-log` → `/var/log/maintenance.jsonl` → (a) Alloy → Loki (2y) and (b) timer → `maintenance.prom` → node_exporter → Prometheus |
| **Visualisation** | Grafana → Prometheus / Loki / Alertmanager datasources (loopback) |
| **State protection** | `observability-backup` → `<dataDir>/backup` → your normal backup |

---

## 9. Secrets

sops-nix, age-encrypted. Wired by `nsops--*` modules that import their service module (structural dependency).

| Secret | File | Format | Consumer | Notes |
|---|---|---|---|---|
| `ALERTMANAGER_ENV` | `sops/alertmanager.env` | **dotenv** | Alertmanager (`EnvironmentFile`, read by systemd as root; owner left root because of DynamicUser); `ntfy-provision` (same file) | Keys used by the stack: `NTFY_ALERTMANAGER_PASSWORD`, `NTFY_READER_PASSWORD`. Other `$VAR`s for Slack/PagerDuty/SMTP are supported. `restartUnits=alertmanager.service` |
| `GRAFANA_ADMIN_PASSWORD`, `GRAFANA_SECRET_KEY` | `sops/grafana.yaml` | yaml | Grafana via `__FILE` variables | owner/group = Grafana user/group; `restartUnits=grafana.service`; wired with `mkDefault` |

`secretsFile` options on both modules allow a per-host override. The `reader` password is what `mon-check.sh` needs as `MON_NTFY_AUTH=reader:<pw>`. `sops.age.keyFile` is set globally in `hosts--core--sops`, not here.

---

## 10. Runtime layout (what is where on a host)

`<D>` = `services.nixlab-observability.dataDir` (default `/data`).

| Path | Owner | Contents |
|---|---|---|
| `<D>/prometheus/prometheus.yml` | prometheus | generated config |
| `<D>/prometheus/rules/alerts.yml` | prometheus | generated rules |
| `<D>/prometheus/data/{wal,chunks_head,…}` | prometheus | TSDB; quarantines `wal.broken-*`, `chunks_head.broken-*` |
| `<D>/loki/loki.yaml` | loki | generated config |
| `<D>/loki/{chunks,wal,compactor,rules/fake/journal.yaml,rules-tmp}` | loki | store, WAL (quarantines `wal.broken-*`), ruler |
| `<D>/grafana/{data/grafana.db,logs,plugins,dashboards/<name>/dashboard.json,provisioning/…}` | grafana | state + provisioned content |
| `<D>/ntfy/{server.yml,user.db,cache.db,attachments/}` | ntfy | generated config, auth DB, message cache |
| `<D>/backup/*.bak` etc. | root | nightly copies |
| `/var/lib/alloy/{config.alloy,data/}` | alloy | generated config, positions |
| `/var/lib/private/alertmanager` | DynamicUser | silences, notification log |
| `/var/lib/node_exporter/*.prom` | prometheus | textfile metrics |
| `/var/log/maintenance.jsonl[.1…]` | root:wheel | maintenance records |
| `/var/lib/prometheus-tsdb-guard/last`, `/var/lib/<unit>-wal-recover/last-recovery` | root | cooldown stamps |

| Service | Port | Binds (default) | uid/gid pinned (stack) |
|---|---|---|---|
| ntfy | 2586 | loopback | 744 |
| Loki HTTP / gRPC | 3100 / 9096 | loopback / loopback | 740 |
| Grafana | 3101 | loopback | 742 |
| Prometheus | 9090 | loopback | 743 |
| Alertmanager | 9093 (9094 off) | loopback | DynamicUser |
| node / smartctl / blackbox / systemd exp. | 9100 / 9633 / 9115 / 9558 | loopback | prometheus / exporter users |
| Alloy | 12345 | loopback | 741 |

Pinned uids differ from the dynamically allocated ones on existing hosts. The `*-permissions` oneshots re-chown data dirs on boot; plan a reboot when changing uids.

---

## 11. Shared helpers (`nixlabLib`)

From `flake/nixos-lib.nix`, injected via `specialArgs`.

**`mkServiceHardening { writablePaths, allowNetwork, allowUnixSockets, allowDevices, allowJIT, extraHardening }`** returns a `serviceConfig` fragment; merge with `// { … }` so a service overrides single keys.
- Baseline: `NoNewPrivileges`, `PrivateTmp`, `ProtectSystem=strict`, `ProtectHome`, `MemoryDenyWriteExecute`, `SystemCallFilter=@system-service`, `ReadWritePaths`.
- Network: `RestrictAddressFamilies=[AF_INET AF_INET6 (+AF_UNIX)]`, or `PrivateNetwork` + `AF_UNIX` when `allowNetwork=false`.
- Unless `allowDevices`: `PrivateDevices`, `ProtectKernelModules/Tunables`, `RestrictNamespaces`, `ProtectControlGroups`, `LockPersonality`.
- `allowJIT`: `MemoryDenyWriteExecute=false`, `SystemCallFilter=""`.
- `extraHardening`: `CapabilityBoundingSet=""`, `RestrictSUIDSGID`, `ProtectKernelLogs`, `ProtectClock`, `ProtectHostname`, `ProtectProc=invisible`, `ProcSubset=pid`, `SystemCallArchitectures=native`, `RemoveIPC`, `UMask=0077`.
- Used by every observability unit with `extraHardening=true`; Alloy adds `allowJIT`; node_exporter and Alloy relax `/proc`; Grafana overrides `UMask=0027`.

**`mkDataDirPermissionsService { pkgs, dataDir, user, group, requiredBy }`** — root oneshot `RequiresMountsFor=dataDir` that `find -xdev … chown -h user:group` anything not owned correctly. Fixes (1) uid/gid drift and (2) the race where tmpfiles `d`/`Z` rules run before a separate `/data` mount exists. Instances: `loki-`, `grafana-`, `ntfy-`, `alloy-`, `prometheus-permissions`; each is `requiredBy` its service.

**`mkWalSelfHeal { pkgs, unit, walDir, user, group, errorPattern, keep=2, cooldownSeconds=3600 }`** — see §12.

**Others used here:** `mkNginxVirtualHost`, `mkFirewallPorts`, `mkSslAssertion` (domain/SSL plumbing, identical across modules).

---

## 12. Resilience mechanisms

| Failure | Detection | Automatic action | Manual follow-up |
|---|---|---|---|
| Clock wrong at boot / sync late | `ClockDrift`, `ClockNotSynced` | Prometheus, Loki, Alloy start `after`/`wants` `time-sync.target`; `hosts--profl--base` makes that target wait for `systemd-time-wait-sync` (60 s timeout) | |
| Prometheus up but TSDB head in the future / samples rejected | `PrometheusHeadInFuture`, `PrometheusSamplesOutOfBounds`, `PrometheusNoRecentSamples` | **`prometheus-tsdb-guard`** (timer: 15 min after boot, then every 5 min): if head is >1h ahead *or* >100 "out of bounds/too far into the future" log lines in 15 min → stop Prometheus, move `data/wal` and `data/chunks_head` to `*.broken-<ts>`, start it. 6-hour cooldown | Fix the clock first. Compacted blocks with future samples need manual removal — `PrometheusHeadInFuture` runbook |
| Prometheus/Loki crash-looping on a corrupt WAL | systemd failure; `PrometheusWALCorruption` | **`mkWalSelfHeal`**: unit gets `StartLimitBurst=3` in 300 s; on failure `<unit>-wal-recover` runs *only if* the last 15 min of journal matches `segments are not sequential\|wal.*corrupt\|corrupt.*wal\|checkpoint.*corrupt`; moves `walDir` to `walDir.broken-<ts>`, recreates it, resets failed state, starts the unit. Max once per hour; keeps 2 quarantines. Cost: data only in the WAL (minutes) is lost | If it fires often, find the cause (disk, power, clock) |
| Prometheus can't store anything (so metric alerts are unreliable) | `absent_over_time` rule | Alertmanager inhibits all other `category=observability` alerts for that instance; notifications still go out | `PrometheusNoRecentSamples` runbook |
| Alerts not reaching you | `PrometheusNoAlertmanager`, `PrometheusNotificationsFailing`, `AlertmanagerNotifyFailing` | — | `bin/mon-check.sh --fire-test` |
| Loki OOM/slow shutdown | — | `TimeoutStopSec=5min`, flush on shutdown | |
| Wrong ownership after rebuild | — | `*-permissions` oneshots every boot | |
| Grafana stale/renamed dashboards | — | pre-start cleanup of provisioned dashboards (daily DB backup first) | |

---

## 13. CI and testing

`flake/ci/observability-checks.nix` (x86_64-linux only; run by `nix flake check`). Hosts checked: `nixnas1` (stable) and `nixsun` (unstable), one per nixpkgs channel.

| Check | What it verifies |
|---|---|
| `prom-config-<host>` | Rendered `prometheus.yml` passes `promtool check config --syntax-only` |
| `prom-rules-<host>` | Rendered rules pass `promtool check rules` |
| `alertmanager-config-<host>` | Config passes `amtool check-config` after dummy-substituting every `$VAR` |
| `prom-rules-all-features` | Every rule with every feature flag on is valid |
| `prom-rule-tests` | `promtool test rules` over `flake/ci/_tests/prometheus/*.test.yml`, rules rendered **without** `condition` label and runbook annotation |
| `runbook-coverage` | Every alert (all features, `expectedMounts=["/data"]`) has `docs/runbooks/<Alert>.md` or a line in `_todo.txt` |
| `dashboard-lint` | Each dashboard JSON has `uid`, `title`, `schemaVersion`; first threshold step is `null`; no unit `days` (use `d`); uids are unique |
| `maintenance-log-shellcheck` | `maintenance-logger.sh` passes shellcheck |

Rule unit tests exist for: HostDown, CriticalDiskSpace (and absence of LowDiskSpace), ProbeFailed, HighCPULoad, NVMeHighTemperature (and absence of HighCPUTemperature), PrometheusConfigReloadFailed, PrometheusNoAlertmanager, SMARTStatusFailed, FilesystemReadOnly, ExpectedMountMissing, ZpoolNotOnline, BatteryHealthDegraded. Expected labels/annotations must match the rule exactly, so changing a summary or label means updating its test.

Other: `nix run .#build-all` builds every host; the pre-commit hooks (alejandra, deadnix, merge-conflict guards) run as a check.

---

## 14. Operations

### 14.1 Scripts (`bin/`, run **on the host**)

| Script | Use |
|---|---|
| `mon-check.sh [--fire-test]` | Verifies: units active (`MON_UNITS`); readiness endpoints for Prometheus, Loki, Alertmanager, Grafana, ntfy; all scrape targets up; no rules in error (reports rules still waiting for first evaluation); Prometheus has ≥1 Alertmanager; Loki has labels. `--fire-test` posts a uniquely named warning to Alertmanager and polls the ntfy topic for up to 90 s (expect 30–60 s: `group_wait`). Exit code 0 = all passed. Env: `MON_HOST`, `MON_PROM_PORT`, `MON_LOKI_PORT`, `MON_GRAFANA_PORT`, `MON_AM_PORT`, `MON_NTFY_PORT`, `MON_TOPIC`, `MON_UNITS`, `MON_NTFY_AUTH=user:pass` (use the `reader` account). Needs `curl`, `jq`. `MON_UNITS` overrides the unit list. |
| `mon-snapshot.sh <outdir>` | Captures normalised `systemctl cat` of each unit (store hashes stripped), generated configs (`prometheus.yml`, `alerts.yml`, `loki.yaml`, `config.alloy`, `ntfy-server.yml`), Alertmanager's live config, listening sockets, and `systemd-analyze security` scores. Run before and after a change, then `diff -ru`. `MON_DATA` overrides `/data`. |
| `mon-unitdiff.sh <old-system> <new-system>` | Diffs generated unit files between two system closures (e.g. `/run/current-system` and `./result`) plus `nix store diff-closures`. Use before switching. |

### 14.2 Routine procedures

**Deploy a change.** `git add -A` → `nix flake check` → `sudo nixos-rebuild switch --flake .#<host>` (or `ltest` first) → `bin/mon-check.sh` → `bin/mon-check.sh --fire-test` after anything touching Alertmanager/ntfy/secrets.

**Rollout.** Deploy to one host, run `bin/mon-check.sh`, then the rest.

**Is it healthy?** Grafana → *System Monitoring & Maintenance Dashboard v5* → health score, alerts table, "Observability Stack Health" row; or `curl -s localhost:9090/api/v1/targets | jq '[.data.activeTargets[]|select(.health!="up")]'`.

**Log a maintenance task.** `sudo maintenance-log --section II.4 --task "Applied updates, rebooted" --status completed`. (File is wheel-writable.) Review in Grafana (Maintenance row) or Loki `{job="maintenance-log"}`.

**Rotate secrets.** See `docs/secrets-rotation.md` (design, `bin/rotate-secret.sh`, per-secret apply steps).

**Silence an alert.** Alertmanager UI (`:9093`, only if exposed) or `amtool --alertmanager.url=http://127.0.0.1:9093 silence add alertname=<X>`.

**Change retention.** `services.nixlab-observability.{loki.retention,prometheus.retention,prometheus.retentionSize}`; Loki needs a restart-time compaction cycle to delete.

**Restore.** Grafana/ntfy/Alertmanager: stop the unit, copy `<D>/backup/<name>.bak` over the DB (`grafana.db.bak` → `<D>/grafana/data/grafana.db`), fix ownership (permissions oneshot does it at next start), start.

### 14.3 Troubleshooting matrix

| Symptom | Look at |
|---|---|
| No notifications at all | `mon-check.sh --fire-test`; `journalctl -u alertmanager`; `alertmanager_notifications_failed_total`; ntfy up? creds in `alertmanager.env` match? → runbook *AlertmanagerNotifyFailing* |
| Prometheus healthy but dashboards empty / `up` missing | Clock (`timedatectl`), `journalctl -u prometheus | grep -i 'out of bounds'`, TSDB head vs now → *PrometheusNoRecentSamples* / *PrometheusHeadInFuture* |
| Prometheus won't start | `promtool check config <D>/prometheus/prometheus.yml`; WAL errors → self-heal should act; `ls <D>/prometheus/data` for `*.broken-*` |
| Target down | `curl localhost:<port>/metrics`; service journal; firewall for remote scrapes (exporters are loopback by default) → *ServiceDown*, *HostDown* |
| Grafana dashboard missing/old | `journalctl -u grafana` (`grafana-setup:` lines); JSON must be `git add`ed; lint rules in §13; uid clashes |
| Grafana panels "No data" for Loki | datasource uid must be `loki`; `curl localhost:3100/loki/api/v1/labels` |
| No logs in Loki | `systemctl status alloy`; `alloy` UI on `127.0.0.1:12345`; `AlloyDroppingEntries`; Loki rate limits (`LokiDiscardingSamples`) |
| Maintenance entries not in Loki | `maintenance.logPath` must not end in `.log`; `loki.maintenance.enable = true`; Alloy can read the file (0664) |
| Alert fires but no runbook link | `runbook` annotation only on deployed rules, requires `runbookBase` (set in `rendered.nix`) |
| `nix flake check` fails `runbook-coverage` | Add `docs/runbooks/<Alert>.md` or a line in `_todo.txt` |
| `nix flake check` fails a rule test | Exact label/annotation match required; test rules have no `condition` label |
| Permission denied on data dir after rebuild | uid changed; `systemctl status <svc>-permissions`; reboot |

---

## 15. Extending the stack

**Add an alert (Prometheus).**
1. Add the rule to the right group in `_internals/maintenance-alerts.nix` (`alert`, `expr`, `for`, `labels.{severity,category,checklist_section}`, `annotations.{summary,description}`; `requires = "<flag>"` if it depends on an optional exporter — define the flag in `rendered.nix`/`options.nix` if new).
2. Write `docs/runbooks/<Alert>.md` from `_template.md` (or add the name to `_todo.txt`).
3. Add a test case to `flake/ci/_tests/prometheus/rules.test.yml`.
4. `git add -A && nix flake check`.

**Add a log alert.** Append a rule to the `journal` group in `stacks/observability.nix` (`services.loki-nixlab.ruler.groups`); set `instance = "{{ $labels.host }}"` plus `severity`, `category`, `checklist_section`. No test/runbook-coverage applies; write a runbook anyway.

**Add a scrape target.** Host-specific: `services.prometheus-nixlab.extraScrapeConfigs = [{ job_name = "x"; static_configs = [{ targets = ["127.0.0.1:1234"]; }]; }];`. Fleet-wide: add a `scrapeJob` to the stack, or an `integrations.*` entry plus an alert feature flag.

**Add a probe.** Set `services.prometheus-nixlab.maintenance.exporters.blackbox.{httpTargets,sslTargets,dnsTargets,tcpTargets,icmpTargets,httpInsecureTargets}` (requires `maintenance.enable`).

**Add a dashboard.** Drop `<name>.json` into `grafana/dashboards/` (needs `uid`, `title`, `schemaVersion`; `steps[0].value = null`; unit `d` not `days`; use `${DS_PROMETHEUS}` or uid `loki`; include the `prometheus_url` constant variable if you want deep-links), `git add`, then either add it to the module's default `dashboards` or enable per host with `extraDashboards = ["<name>"]`.

**Add a receiver/channel.** Set `notifications.useNtfy = false` (or add alongside), define `services.alertmanager-nixlab.receivers` and `route.routes`, put secrets in `alertmanager.env` as `KEY=value` and reference `$KEY`. Receiver names are asserted at eval time.

**Add a monitored service to the fleet** (e.g. a new `servc--foo-nixlab`): expose a `/metrics`, add a stack `scrapeJob`, add alerts/runbooks, optionally a dashboard.


---

## 16. Open issues and sharp edges


---

## 17. Quick reference

**Option paths you will actually touch**
```
services.nixlab-observability.{enable, access.{interfaces,expose}, publicHost, dataDir,
                            prometheus.{maintenance.enable,retention,retentionSize,scrapeInterval},
                            loki.{retention,maintenance.enable}, notifications.{ntfyAuth.enable,separateCritical,useNtfy},
                            integrations.*, probes.*}
services.prometheus-nixlab.{extraScrapeConfigs, maintenance.expectedMounts, maintenance.exporters.blackbox.*, maintenance.exporters.smartctl.devices}
services.alertmanager-nixlab.{receivers, route.routes, inhibitRules, extraConfig}
services.grafana-nixlab.{extraDashboards, allowAnonymous, provisioning.datasources}
services.loki-nixlab.ruler.groups
services.host-exporters-nixlab.{nodeExporter.listenAddress, smartctl.listenAddress}
services.maintenance-log-nixlab.{logPath, textfileDir}
```

**Useful commands**
```bash
# state
systemctl status prometheus loki alloy grafana alertmanager ntfy prometheus-node-exporter
curl -s localhost:9090/api/v1/rules  | jq '[.data.groups[].rules[]|select(.health!="ok")]'
curl -s localhost:9090/api/v1/alerts | jq '.data.alerts[]|{alertname:.labels.alertname,state}'
curl -s localhost:9093/api/v2/alerts | jq '.[].labels.alertname'
curl -s localhost:3100/loki/api/v1/labels
curl -s localhost:2586/v1/health
# validate
promtool check config /data/prometheus/prometheus.yml
nix build .#checks.x86_64-linux.prom-rule-tests
nix flake check
# verify
bin/mon-check.sh ; MON_NTFY_AUTH=reader:<pw> bin/mon-check.sh --fire-test
bin/mon-snapshot.sh /tmp/before ; # change ; bin/mon-snapshot.sh /tmp/after ; diff -ru /tmp/before /tmp/after
bin/mon-unitdiff.sh /run/current-system ./result
```

**Naming.** `servc--<svc>-nixlab` atomic service module · `nsops--<svc>` secrets wiring · `stack--observability` aggregator · `systm--ports-<svc>` port defaults (`mkDefault`) · `systm--<thing>-nixlab` cross-cutting helper modules · `flake.lib.<name>` shared functions/data consumed by name.

---

## Appendix: illustrative host configuration

*Derived from the option definitions, not copied from a host file (none were provided). Adapt names and interfaces.*

```nix
# hosts/nixnas1.nix — modules = [ ... self.nixosModules.stack--observability ... ]
services.nixlab-observability = {
  enable = true;
  access = {
    interfaces = [ "eno1" ];                       # wired only
    expose = [ "grafana" "ntfy" "prometheus" ];
  };
  prometheus = {
    maintenance.enable = true;                     # loads the full alert set + exporters
    retentionSize = "50GB";
  };
  loki.maintenance.enable = true;                  # maintenance-log helper + Alloy pipeline
  notifications.ntfyAuth.enable = true;            # needs NTFY_*_PASSWORD in sops/alertmanager.env
};

services.prometheus-nixlab.maintenance.expectedMounts = [ "/data" ];
services.grafana-nixlab.extraDashboards = [ "zfs-monitoring" ];   # ZFS host only
```
