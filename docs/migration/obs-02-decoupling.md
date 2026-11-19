# Observability Flake — Guide 2 of 3: Decoupling (step-by-step edition)

> **Goal:** make the observability flake stand on its own. When you finish, it needs **no special arguments**, **no `nixlab` options**, **no `nixlab` host data**, and **no sops-nix** unless a consumer chooses it. `nixlab` uses it through one small adapter file.
>
> **Still behaviour-preserving.** Your hosts must end up running exactly what they run today. You will prove that with a before/after comparison (Part 11).
>
> **Not in this guide:** renaming things, moving directories, new alerts. That is Guide 3.
>
> **Honesty note:** I have not run this Nix against your repository. Every step ends with a **Check** so *your machine* tells you whether it worked. If a Check disagrees with this guide, trust the Check and look at *If it fails*.

---

## How to read this guide

Every step has the same shape:

| Label | Meaning |
|---|---|
| **Where** | Which directory to run commands in (`$OBS` = observability repo, `$NIXLAB` = nixlab repo). |
| **Do** | Exactly what to type or edit. |
| **Check** | A command and what you should see. **Do not move on until it matches.** |
| **If it fails** | The usual causes. |
| **Commit** | The git command to save the step. One logical change per commit. |

Commands are for a Linux shell with Nix and git. Lines starting with `#` are comments, do not type them.

### Plan at a glance

| Part | What you do | Repo |
|---|---|---|
| 1 | Prepare and take a "before" snapshot | both |
| 2 | Write the tests first (they will fail on purpose) | `$OBS` |
| 3 | Move the helper functions into `$OBS` | `$OBS` |
| 4 | Remove the hidden "main user" dependency | `$OBS` |
| 5 | Remove host-metadata and service-registry dependency | `$OBS` |
| 6 | Fix two boundary problems (Loki/Alloy, maintenance log) | `$OBS` |
| 7 | Make secrets independent of sops-nix | `$OBS` |
| 8 | Make the runbook URL an option | `$OBS` |
| 9 | Finish the public interface, docs and example; tag a release candidate | `$OBS` |
| 10 | Switch `nixlab` over (adapter) | `$NIXLAB` |
| 11 | Prove nothing changed ("parity") | `$NIXLAB` |
| 12 | Deploy to one host, then all, and release | both |

**Parts 3–9 only touch the observability repo.** `nixlab` stays untouched and working until Part 10. That is deliberate: you can always stop, and nothing in production changes until Part 12.

---

## 0. Background (read once)

### 0.1 Entry gate

Do not start until **all** are true:

- [ ] Guide 1's final checklist is ticked (all hosts migrated, soak finished).
- [ ] `nixlab`'s `flake.nix` pins the observability input to tag `v0.1.0`, and both repos' `main` branches are clean.
- [ ] In `$OBS`, this prints the seam list S1, S2, S4, S5, S6, S7, S8 (your work list):

```bash
cd $OBS && git grep -n M2-REMOVE -- . ':!docs'
```

### 0.2 What your Guide 1 parity diff told us (verdict: passed)

| Finding | Evidence | Verdict |
|---|---|---|
| Alert-rule changes are only the runbook URL | 420 changed line pairs = 7 hosts × 60 rules; none differ by anything except `Temhr/nixlab` → `Temhr/observability` | ✅ exactly the intended change |
| Unit changes | 14 lines = one `prometheus-pre-start` store hash per host (that script embeds the rules file, whose content changed) | ✅ expected |
| Everything else captured (alertmanager, loki rules, datasources, alloy extra config, firewall, users) | no diff on any host | ✅ identical |

Two limits of that evidence, fixed by a **bigger capture script** in Part 1: it covered only eight systemd units, and missed sops secrets, tmpfiles rules, nginx hosts, and the permission/WAL/provision/backup units.

### 0.3 What your host files tell us

I read all seven hosts and both profiles. The **entire** way your fleet configures observability is:

| Where | Setting |
|---|---|
| `profile-base` | enables the stack and the maintenance flags |
| `profile-desktop` | `services.nixlab-observability.access.interfaces = [hostMeta.ethIface hostMeta.wifiIface]`, `services.prometheus-nixlab.maintenance.expectedMounts = ["/data"]` |
| `profile-nas` | the same two, with `["/mirror"]` and `[hostMeta.ethIface]` |
| `nixnas1` | `services.grafana-nixlab.extraDashboards = ["zfs-monitoring"]` |

**No host sets:** `probes.*`, `enableAlloy`, `alloyPort`, `alloyPackage`, any `secretsFile`, any observability `extraUsers`, or `publicHost`. So this guide **needs no edit to any `hosts/*.nix` file**, and at most one small edit to one profile.

> **Something worth your attention (not changed in this guide).** The option documentation for `access.interfaces` says *"never list a Wi-Fi interface"*, yet `profile-desktop` passes `wifiIface` on every desktop and laptop. That means Grafana, ntfy and Prometheus are reachable over Wi-Fi on those machines. Maybe that is intended, but the code and its own documentation disagree. Decide which is right in Guide 3. This guide keeps today's behaviour so the parity check stays meaningful.

### 0.4 Decisions already made for you

| # | Decision | Why |
|---|---|---|
| D1 | Helpers become `flake.lib.obsLib`; modules read them from the flake's own `self`, not a module argument. | A module argument is a hidden contract any consumer must remember to supply. |
| D2 | All six helpers move, function bodies **unchanged**. | Your code uses all six (nginx, firewall, SSL, hardening, permissions, WAL recovery). Unchanged bodies keep the comparison clean. |
| D3 | Write the tests first; watch them fail; then fix. | You cannot accidentally leave a dependency behind. |
| D4 | The nixlab adapter keeps the name `stack--observability-nixlab`. | Hosts keep importing the same name. |
| D5 | Removed options get "renamed option" aliases for one release, only when a replacement exists. | Nobody sets the dead ones (§0.3), so aliases for them would be clutter. |
| D6 | sops-nix becomes optional; the adapter imports the sops modules, not the stack. | The biggest barrier to a non-nixlab user. |
| D7 | In the adapter use `mkDefault` for values that used to be option defaults; **plain** assignment for `extraUsers`. | `mkOptionDefault` clashes with the option's own default; a `mkDefault` list would be silently dropped if a host set its own. |

### 0.5 Glossary

| Term | Plain meaning |
|---|---|
| **flake** | A Nix project with a `flake.nix`, a lock file, and standard outputs. |
| **input / lock file** | Another flake you depend on; `flake.lock` pins the exact version. |
| **module / option** | A NixOS building block; an option is a setting it exposes, e.g. `services.loki-nixlab.port`. |
| **check** | A named test defined in the flake. Run with `nix build .#checks.x86_64-linux.<name>`. Success = exit code 0. |
| **harness** | A fake machine (not real hardware) our tests build, to prove the modules work for a stranger. |
| **seam** | A temporary dependency on `nixlab` we deliberately left during Guide 1 (tagged `M2-REMOVE`). |
| **adapter** | The one nixlab file that translates nixlab's facts into the observability flake's options. |
| **parity** | "Before and after are identical." |
| **canary** | Deploying to one low-risk host first. |
| **red / green** | A failing / passing test. Part 2 deliberately makes tests red; Parts 3–9 turn them green. |

### 0.6 Toolbox (the six things you'll do repeatedly)

**T1 — Run one check.**
```bash
cd $OBS
nix build .#checks.x86_64-linux.NAME --print-build-logs
```
It prints nothing scary and returns you to the prompt = **pass**. A block starting with `error:` = **fail**. A passing check leaves a harmless `result` symlink; delete with `rm -f result`. First builds download a lot and can take 10–30 minutes.

**T2 — List all checks.**
```bash
nix eval .#checks.x86_64-linux --apply builtins.attrNames
```

**T3 — Run all checks.** `nix flake check --print-build-logs`.

**T4 — Understand an error.** Re-run with `--show-trace` and read from the **top** of the `error:` block: the first line says *what* is wrong, nearby lines say *which file and line*. Example: `error: function … called without required argument 'nixlabLib'` means some module still expects an argument nobody supplies.

**T5 — Find the line to edit.**
```bash
grep -rn "text to find" modules stacks sops flake
```
Output is `path:LINE:text`. Open that file at that line in your editor.

**T6 — Edit safely.** After any edit:
```bash
nix fmt            # re-formats Nix files (alejandra) so diffs stay small
git diff           # read your change; it should be exactly what the step said
```

**T7 — The golden rule of flakes + git.**
```bash
git add -A         # BEFORE any nix command
```
Nix ignores files git doesn't know about. "File not found" for a file you just created almost always means you forgot `git add`.

**T8 — Undo.** Uncommitted edit to one file: `git restore path/to/file`. Throw away **all** uncommitted edits: `git restore .` (careful, irreversible). A commit you regret: `git revert <hash>`.

### 0.7 Environment file (do this now, once)

Variables vanish when a terminal closes. Save them:

```bash
cat > ~/obs-env.sh <<'EOF'
export NIXLAB=~/nixlab
export OBS=~/observability
export BASELINE=~/obs-baseline
# Fast progress meter: lists every remaining nixlab dependency in the observability repo.
seams() {
  (cd "$OBS" && grep -rEn --exclude=observability-checks.nix \
    'nixlabLib|hostMeta|allHosts|hostsMeta|serviceRegistry|config\.nixlab|M2-REMOVE|self\.nixosConfigurations' \
    modules stacks sops flake)
}
EOF
source ~/obs-env.sh
```

Add `source ~/obs-env.sh` to the top of every new terminal. Then:

```bash
seams | wc -l      # how many dependency lines remain. This number goes down to 0.
```

---

## Part 1 — Prepare and snapshot "before"

### 1.1 Create branches

**Where:** both repos.
```bash
cd $OBS    && git switch main && git pull && git switch -c decouple
cd $NIXLAB && git switch main && git pull && git switch -c obs-decouple
git tag pre-obs-decouple        # still in $NIXLAB; a bookmark you can always return to
```
**Check:** `git -C $OBS branch --show-current` prints `decouple`; `git -C $NIXLAB branch --show-current` prints `obs-decouple`; `git -C $NIXLAB tag -l pre-obs-decouple` prints the tag.

### 1.2 Take the "before" snapshot (from a **clean** copy)

Why a clean copy: `Git tree … is dirty` warnings mean uncommitted changes are being measured, and a baseline must describe a committed state.

**Do:** save your corrected `capture2.sh` (use the version that has `builtins.length c.assertions`; the old `== [] ||` form errors). Then:

```bash
cd $NIXLAB
git worktree add /tmp/nixlab-before pre-obs-decouple
(cd /tmp/nixlab-before && bash $BASELINE/capture2.sh $BASELINE/before2)
git worktree remove /tmp/nixlab-before
```

**Check:** no `error:` text; no `dirty` warnings; and:
```bash
ls $BASELINE/before2/nixnas1
```
lists at least: `alertmanager.json alloy-extra.json assertion-count.json datasources.json firewall-ifaces.json firewall-tcp.json groups.json loki-ruler.json nginx-vhosts.json prometheus-rendered.json sops-secrets.json tmpfiles.json toplevel units-aux.json units.json users.json`.
```bash
find $BASELINE/before2 -name '*.json' -size 0       # prints nothing = no empty files
```

**If it fails:** an `error:` in one `ev` line means that value can't be serialised on some host. Delete or fix **only that line**, then rerun **from scratch into a new empty directory**. Never compare two directories made by different versions of the script. It will take a while; it builds all 7 hosts.

### 1.3 Check the Wi-Fi interface question now

```bash
for h in nixnas1 nixnas2 nixace nixsun nixtop nixvat nixzen; do echo "== $h"; cat $BASELINE/before2/$h/firewall-ifaces.json; done
```
**Look for** an interface named `""` (two quotes, empty). **Write down yes or no.** If yes, Part 10.3 applies to you; if no, skip it.

No commit needed. Part 2 begins.

---

## Part 2 — Write the tests first (they will fail on purpose)

### 2.1 The public API document

**Where:** `$OBS`. Create `docs/architecture/public-api.md`:

```markdown
# Public API (v0.2)

## Stability
Pre-1.0: a minor version may break. Everything not listed as "public" is internal.

## Public NixOS modules (names are the contract)
| Module | Purpose | Enabled by |
|---|---|---|
| stack--observability | the whole stack, wired together | services.nixlab-observability.enable |
| servc--{prometheus,alertmanager,ntfy,loki,alloy,grafana}-nixlab | one service, usable alone | services.<name>-nixlab.enable |
| systm--host-exporters-nixlab, systm--maintenance-log-nixlab, systm--observability-backup-nixlab | supporting capabilities | their own `enable` |
| nsops--alertmanager, nsops--grafana | OPTIONAL sops-nix secret wiring | import them yourself |

Importing a module never starts anything; each has an `enable`.

## What a consumer must provide
- Nothing except `enable`.
- If ntfy auth is on: `notifications.ntfyAuth.environmentFile` (defaults to Alertmanager's `environmentFile`).
- If you use the nsops modules: `secretsFile` per service, plus sops-nix with a key source.
- For remote access: `access.interfaces` (default: loopback only).
- Optional context: `publicHost`, `probes.gateway`, `probes.icmpTargets`, `probes.tcpTargets`, `*.extraUsers`.

## Host prerequisites (documented, not enforced)
`dataDir` (default `/data`, each service gets a subdirectory) is mounted before the stack starts;
time sync reaches `time-sync.target`; journald; nginx only if a service sets `domain`.

## Internal (no promise)
`self.lib.obsLib`, `_internals/`, `systm--ports-*`, the test harness.
```

**Commit:** `git add -A && git commit -m "docs: public API (draft)"`

### 2.2 The decision records

You received five files (ADR-003, 005, 006, 008, 009 and an index). Copy them in:

```bash
cd $OBS
mkdir -p docs/architecture/decisions
cp /path/to/decisions/*.md docs/architecture/decisions/
git add -A && git commit -m "docs(adr): record decisions 003, 005, 006, 008, 009"
```
**Check:** `ls docs/architecture/decisions` shows six files.

### 2.3 Replace the test harness

The harness builds a fake machine. This version passes **no special arguments** and has **no `nixlab` option**: a stranger's machine.

**Where:** `$OBS`. **Do:** replace the **entire contents** of `flake/ci/_harness/default.nix` with:

```nix
# Test harness: builds fake machines that behave like an outside consumer.
# It passes NO specialArgs on purpose. If a module still needs one, evaluation fails here.
{
  inputs,
  self,
}: let
  base = {...}: {
    networking.hostName = "testhost";
    system.stateVersion = "24.11";
    boot.loader.grub.enable = false;
    fileSystems."/" = {
      device = "none";
      fsType = "tmpfs";
    };
  };
in {
  mkTestHost = {
    nixpkgs ? inputs.nixpkgs,
    modules ? [],
  }:
    nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [self.nixosModules.stack--observability base] ++ modules;
    };

  # A consumer who uses sops-nix and the optional nsops modules (nixlab's situation).
  withSops = {pkgs, ...}: {
    imports = [
      inputs.sops-nix.nixosModules.sops
      self.nixosModules.nsops--alertmanager
      self.nixosModules.nsops--grafana
    ];
    sops.age.keyFile = "/var/lib/sops-nix/key.txt";
    sops.validateSopsFiles = false;
    services.alertmanager-nixlab.secretsFile = pkgs.writeText "alertmanager.env" "";
    services.grafana-nixlab.secretsFile = pkgs.writeText "grafana.yaml" "";
  };

  # A stranger with some other secret manager: sops-nix is not in the module set at all.
  withoutSops = {
    services.alertmanager-nixlab.environmentFile = "/run/secrets/alertmanager.env";
    services.grafana-nixlab.credentialsFile = "/run/secrets/grafana-admin";
    services.grafana-nixlab.secretKeyFile = "/run/secrets/grafana-secret-key";
  };

  # Everything switched on: exercises every optional branch.
  fullStack = {
    services.nixlab-observability = {
      enable = true;
      publicHost = "192.0.2.10";
      probes.gateway = "192.0.2.1";
      probes.icmpTargets = ["192.0.2.20"];
      probes.tcpTargets = ["127.0.0.1:8080"];
      access.interfaces = ["eth0"];
      notifications.ntfyAuth.enable = true;
      notifications.topics.storage.matchers = ["category=~\"storage|backup\""];
      loki.maintenance.enable = true;
      prometheus.maintenance.enable = true;
      prometheus.maintenance.exporters.systemd = true;
      integrations.traefik.enable = true;
      integrations.cadvisor.enable = true;
      integrations.postgres.enable = true;
    };
  };

  minimalStack = {services.nixlab-observability.enable = true;};
}
```

> `192.0.2.x` is a reserved documentation address range: safe, never routable. Options such as `probes.icmpTargets` do not exist **yet**; Part 5 adds them. That is why the tests are red now.

### 2.4 Confirm the shared per-host checks file exists

Guide 1 §4.7 created `flake/ci/host-checks.nix`. **Check:** `ls $OBS/flake/ci/host-checks.nix`. If it does **not** exist, create it with:

```nix
{self, ...}: {
  flake.lib.observabilityHostChecks = {
    pkgs,
    name,
    hostConfig,
  }: let
    inherit (self.lib) prometheusRendered;
    toJson = n: value: pkgs.writeText n (builtins.toJSON value);
    tools = [pkgs.prometheus.cli pkgs.prometheus-alertmanager pkgs.remarshal pkgs.gettext];
    rendered = prometheusRendered {
      config = hostConfig;
      lib = pkgs.lib;
    };
  in {
    "prom-config-${name}" = pkgs.runCommand "prom-config-${name}" {nativeBuildInputs = tools;} ''
      remarshal -i ${toJson "prometheus.json" rendered.prometheusConfig} -if json -of yaml -o prometheus.yml
      promtool check config --syntax-only prometheus.yml
      touch $out
    '';
    "prom-rules-${name}" = pkgs.runCommand "prom-rules-${name}" {nativeBuildInputs = tools;} ''
      remarshal -i ${toJson "rules.json" rendered.rules} -if json -of yaml -o rules.yml
      promtool check rules rules.yml
      touch $out
    '';
    "alertmanager-config-${name}" = pkgs.runCommand "alertmanager-config-${name}" {nativeBuildInputs = tools;} ''
      remarshal -i ${toJson "am.json" hostConfig.services.prometheus.alertmanager.configuration} -if json -of yaml -o am.yml
      for v in $(grep -o '\$[A-Z_][A-Z0-9_]*' am.yml | tr -d '$' | sort -u); do export "$v=dummy"; done
      envsubst < am.yml > am.sub.yml
      amtool check-config am.sub.yml
      touch $out
    '';
  };
}
```

### 2.5 Replace the checks file

This is where "host-checks on stable, unstable and external" and "build toplevel-external and toplevel-minimal" get **defined**. Each name becomes a check you can run.

**Where:** `$OBS`. **Do:** replace the **entire contents** of `flake/ci/observability-checks.nix` with:

```nix
# Build-time validation of the observability stack's generated configuration.
{
  self,
  inputs,
  lib,
  ...
}: {
  perSystem = {
    pkgs,
    system,
    ...
  }: let
    inherit (self.lib) prometheusMaintenanceAlerts;
    toJson = name: value: pkgs.writeText name (builtins.toJSON value);
    tools = [pkgs.prometheus.cli pkgs.prometheus-alertmanager pkgs.remarshal pkgs.gettext];
    allFeatures = {
      traefik = true;
      containers = true;
      postgres = true;
      backup = true;
      dns = true;
      blackboxProbes = true;
      alertmanagerWired = true;
    };

    # Fake machines. Names become check names: prom-config-<name>, toplevel-<name>, ...
    harness = import ./_harness {inherit inputs self;};
    hosts = {
      # a nixlab-like consumer (uses sops-nix + nsops modules), stable nixpkgs
      stable = harness.mkTestHost {modules = [harness.fullStack harness.withSops];};
      # same, on unstable nixpkgs
      unstable = harness.mkTestHost {
        nixpkgs = inputs.nixpkgs-unstable;
        modules = [harness.fullStack harness.withSops];
      };
      # a stranger: no sops-nix at all
      external = harness.mkTestHost {modules = [harness.fullStack harness.withoutSops];};
      # smallest possible: only `enable = true`
      minimal = harness.mkTestHost {modules = [harness.minimalStack];};
    };
  in {
    checks = lib.optionalAttrs (system == "x86_64-linux") (
      # prom-config-<h>, prom-rules-<h>, alertmanager-config-<h> for each of these three
      (lib.foldl' (acc: name:
          acc
          // self.lib.observabilityHostChecks {
            inherit pkgs name;
            hostConfig = hosts.${name}.config;
          }) {} ["stable" "unstable" "external"])
      // {
        # Whole-system build of three fake machines.
        toplevel-stable = hosts.stable.config.system.build.toplevel;
        toplevel-external = hosts.external.config.system.build.toplevel;
        toplevel-minimal = hosts.minimal.config.system.build.toplevel;

        # Fails while ANY nixlab-internal dependency remains in this repository.
        no-nixlab-coupling = pkgs.runCommand "no-nixlab-coupling" {nativeBuildInputs = [pkgs.gnugrep];} ''
          cd ${self}
          if grep -rEn --exclude=observability-checks.nix \
              'nixlabLib|hostMeta|allHosts|hostsMeta|serviceRegistry|config\.nixlab|M2-REMOVE|self\.nixosConfigurations' \
              modules stacks sops flake; then
            echo "nixlab-internal coupling found (see matches above)" >&2
            exit 1
          fi
          touch $out
        '';

        # Every alert needs docs/runbooks/<Alert>.md, unless it is listed in docs/runbooks/_todo.txt.
        runbook-coverage = pkgs.runCommand "runbook-coverage" {nativeBuildInputs = [pkgs.jq];} ''
          jq -r '.groups[].rules[] | select(.alert) | .alert' ${toJson "rules-all-names.json" {
            groups =
              (prometheusMaintenanceAlerts {
                features = allFeatures;
                expectedMounts = ["/data"];
              }).groups;
          }} | sort -u > alerts.txt
          missing=0
          for a in $(cat alerts.txt); do
            if [ ! -f ${self}/docs/runbooks/$a.md ] && ! grep -qx "$a" ${self}/docs/runbooks/_todo.txt; then
              echo "no runbook for $a"; missing=1
            fi
          done
          [ $missing = 0 ]
          touch $out
        '';

        # Dashboards must carry a uid and schemaVersion, use valid units and thresholds, and not clash.
        dashboard-lint = pkgs.runCommand "dashboard-lint" {nativeBuildInputs = [pkgs.jq];} ''
          cd ${self.lib.grafanaDashboards}
          for f in *.json; do
            jq -e '.uid and .title and .schemaVersion' "$f" >/dev/null || { echo "$f: needs uid, title and schemaVersion"; exit 1; }
            jq -e '[.. | objects | select(has("steps")) | .steps[0].value] | all(. == null)' "$f" >/dev/null || { echo "$f: the first threshold step must be null"; exit 1; }
            jq -e '[.. | objects | .unit? // empty] | index("days") | not' "$f" >/dev/null || { echo "$f: unit days is invalid (use d)"; exit 1; }
          done
          jq -s -e '[.[].uid] | length == (unique | length)' *.json >/dev/null || { echo "duplicate dashboard uids"; exit 1; }
          touch $out
        '';

        # The maintenance helper script must pass shellcheck.
        maintenance-log-shellcheck = pkgs.runCommand "maintenance-log-shellcheck" {nativeBuildInputs = [pkgs.shellcheck];} ''
          shellcheck -s bash ${self.lib.maintenanceLoggerScript}
          touch $out
        '';

        # Validates every rule, including the ones gated behind feature flags.
        prom-rules-all-features = pkgs.runCommand "prom-rules-all-features" {nativeBuildInputs = tools;} ''
          remarshal -i ${toJson "rules-all.json" {groups = (prometheusMaintenanceAlerts {features = allFeatures;}).groups;}} -if json -of yaml -o rules.yml
          promtool check rules rules.yml
          touch $out
        '';

        # Runs the unit tests in ./_tests/prometheus against the rules (without the condition label).
        prom-rule-tests = pkgs.runCommand "prom-rule-tests" {nativeBuildInputs = tools;} ''
          mkdir work && cd work
          remarshal -i ${toJson "rules-no-condition.json" {
            groups =
              (prometheusMaintenanceAlerts {
                features = allFeatures;
                conditionLabel = false;
                expectedMounts = ["/data"];
              }).groups;
          }} -if json -of yaml -o alerts.yml
          cp ${./_tests/prometheus}/*.test.yml .
          promtool test rules *.test.yml
          touch $out
        '';
      }
    );
  };
}
```

> This file must stay in `flake/ci/`: `${./_tests/prometheus}` is a path **relative to this file**.

### 2.6 Prove the wiring (and watch it go red)

**Where:** `$OBS`.

**Do 1 — the checks exist.**
```bash
git add -A
nix eval .#checks.x86_64-linux --apply builtins.attrNames
```
**Check:** a list containing all of these (order may vary):
```
alertmanager-config-external  alertmanager-config-stable  alertmanager-config-unstable
dashboard-lint  maintenance-log-shellcheck  no-nixlab-coupling  pre-commit-check
prom-config-external  prom-config-stable  prom-config-unstable
prom-rule-tests  prom-rules-all-features  prom-rules-external  prom-rules-stable  prom-rules-unstable
runbook-coverage  toplevel-external  toplevel-minimal  toplevel-stable
```
If one is missing, you mistyped the file; compare with §2.5.

**Do 2 — see the coupling guard fail.**
```bash
nix build .#checks.x86_64-linux.no-nixlab-coupling --print-build-logs 2>&1 | tail -40
seams | wc -l
```
**Check (this is success for this step):** the build **fails**, printing lines like `modules/nixos/observability/loki/default.nix:7:      nixlabLib,`, and ends with `nixlab-internal coupling found`. `seams | wc -l` prints a number (probably 30–60). **Write it down.** Your goal is 0.

**Do 3 — see a machine fail to build.**
```bash
nix build .#checks.x86_64-linux.toplevel-external --no-link --show-trace 2>&1 | tail -30
```
**Check (success = failure):** an `error:` mentioning something like `called without required argument 'nixlabLib'` or an option that "does not exist" (`probes.icmpTargets`). That proves the harness is a real stranger. These errors are what Parts 3–9 remove.

> **Do not push this.** Your `decouple` branch is allowed to be red; `main` is not.

**Commit:**
```bash
git add -A && git commit -m "test: contract harness and coupling guard (intentionally failing)"
```

---

## Part 3 — Helpers: the observability flake owns them (seam S1)

### 3.1 Rename the helper file

**Where:** `$OBS`.
```bash
mkdir -p flake/lib
git mv flake/nixos-lib.nix flake/lib/obs-lib.nix
```
**Do:** open `flake/lib/obs-lib.nix`. Make exactly these two changes (leave all functions alone):

1. Replace the comment block at the very top (the one saying *verbatim copy*, *specialArgs*, *Receive in any module with…*) with:
   ```nix
   # Observability-owned helper functions. Internal: no stability promise before 1.0.
   # Use from a module registered in this flake:  obsLib = self.lib.obsLib;
   ```
2. Change `flake.lib.nixlabLib = {` to `flake.lib.obsLib = {`.

In any remaining *comments* that say `nixlabLib.mkSomething`, change them to `obsLib.mkSomething`.

**Check:**
```bash
git add -A
grep -n "flake.lib" flake/lib/obs-lib.nix        # shows: flake.lib.obsLib = {
nix eval .#lib.obsLib --apply builtins.attrNames
```
The second command lists **six** names: `mkDataDirPermissionsService mkFirewallPorts mkNginxVirtualHost mkServiceHardening mkSslAssertion mkWalSelfHeal`.

**If it fails:** `attribute 'obsLib' missing` → step 2 wasn't saved or `git add` was skipped.

### 3.2 Rename every use

```bash
grep -rln nixlabLib modules stacks sops flake/lib | xargs sed -i 's/nixlabLib/obsLib/g'
git diff --stat       # shows ~10 files changed
```

> **Do not include `flake/ci` in that command.** `flake/ci/observability-checks.nix` contains the text `nixlabLib` *inside the coupling guard's search pattern*. Renaming it there turns the guard into a check that fails on every `obsLib` (every line of every module). If you already ran the wider version, repair it in §3.2b.

### 3.2b Repair the coupling guard if the sed hit it

```bash
grep -n "obsLib|hostMeta" flake/ci/observability-checks.nix
```
If that prints a line (the guard's search pattern, starting `'obsLib|hostMeta|allHosts|…`), change the **first word only** back:

```diff
-              'obsLib|hostMeta|allHosts|hostsMeta|serviceRegistry|config\.nixlab|M2-REMOVE|self\.nixosConfigurations' \
+              'nixlabLib|hostMeta|allHosts|hostsMeta|serviceRegistry|config\.nixlab|M2-REMOVE|self\.nixosConfigurations' \
```
If it prints nothing, the guard is intact.

### 3.3 Fix the module headers by hand (per file)

After the rename each module still lists `obsLib,` as an *argument* that nobody supplies. Fix each file below.

**Pattern**, shown with Loki, whose header is:

*before (after the sed):*
```nix
{self, ...}: {
  flake.nixosModules.servc--loki-nixlab = {
    config,
    lib,
    pkgs,
    obsLib,
    ...
  }: let
    cfg = config.services.loki-nixlab;
  in {
```
*after:*
```nix
{self, ...}: {
  flake.nixosModules.servc--loki-nixlab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.loki-nixlab;
    obsLib = self.lib.obsLib;
  in {
```
Two changes: **delete** the `obsLib,` line, and **add** `obsLib = self.lib.obsLib;` inside the existing `let`.

Apply to each file (check the *outer* first line):

| File | Outer function today | What to do |
|---|---|---|
| `modules/nixos/observability/loki/default.nix` | `{self, ...}:` | pattern above |
| `…/alertmanager/default.nix` | `{self, ...}:` | pattern above |
| `…/grafana/default.nix` | `{self, ...}:` | pattern above |
| `…/ntfy/default.nix` | `{self, ...}:` | pattern above |
| `…/alloy/default.nix` | `{...}:` | pattern above **and** change the first line to `{self, ...}: {` |
| `…/host-exporters/default.nix` | `{...}:` | pattern above **and** change the first line to `{self, ...}: {` |
| `…/prometheus/default.nix` | `{self, ...}:` | pattern above (it also passes `obsLib` down; see below) |

**Prometheus has helper files underneath.** In `prometheus/default.nix` the line
`prometheusConfig = import ./_internals/config.nix {inherit config lib pkgs obsLib;};`
is already correct after the sed. The three files below are *plain functions* that receive `obsLib` from their caller, so they need **no edit** beyond the rename:

- `prometheus/_internals/config.nix`
- `prometheus/_internals/services/prometheus.nix`
- `prometheus/_internals/extras/nginx.nix`

> The `let` may already contain `cfg = …;`; just add the new line beside it. In `alloy/default.nix` the `let` begins with `cfg = config.services.alloy-nixlab;`.

### 3.4 Check

```bash
nix fmt
git add -A
grep -rn nixlabLib modules stacks sops flake | wc -l       # must print 0
seams | wc -l                                               # smaller than before
nix build .#checks.x86_64-linux.toplevel-external --no-link --show-trace 2>&1 | grep -m3 error
```
The **last command should now complain about something other than `nixlabLib`/`obsLib`**. If it still says `obsLib` is missing, a module in §3.3's table still lacks the `let` binding or the `self` argument; the trace names the file.

**If it fails:** `undefined variable 'self'` → that module's outer line is still `{...}:`; change to `{self, ...}:`. `attribute 'obsLib' missing` in `_internals` → the caller didn't pass it down; look for `import ./… {inherit … }` lines that lack `obsLib`.

**Commit** (this commit contains **only** this change):
```bash
git commit -am "refactor(helpers): own helpers as obsLib, bound from flake scope (S1)"
```

---

## Part 4 — Remove the hidden "main user" dependency (seam S6)

Five modules quietly add `nixlab.mainUser` to each service's group so you can read its data. The *replacement* already exists: every service has an `extraUsers` option. You are only deleting the implicit part (the nixlab adapter will pass it in Part 10).

### 4.1 Find them

```bash
cd $OBS
grep -rn "nixlab ? mainUser" modules
```
**Check:** **five** results: `loki/default.nix`, `grafana/default.nix`, `alloy/default.nix`, `ntfy/default.nix`, `prometheus/_internals/config.nix`.

### 4.2 Replace three lines in each

In each file you'll see (indentation varies):

*before:*
```nix
            ++ lib.optionals (config.nixlab ? mainUser && config.nixlab.mainUser != "")
            (map (u: {${u} = {extraGroups = [cfg.group];};})
              ([config.nixlab.mainUser] ++ cfg.extraUsers))
```
*after (one line):*
```nix
            ++ map (u: {${u} = {extraGroups = [cfg.group];};}) cfg.extraUsers
```
Everything else in the surrounding code stays. Also, in each module's `extraUsers` description, remove any sentence saying `mainUser` is added automatically. A good description is: *"Extra users added to the service's group (for example, to read its data)."*

### 4.3 Check

```bash
nix fmt && git add -A
grep -rn "nixlab ? mainUser\|config.nixlab" modules | wc -l     # must print 0
seams | wc -l
```

**If it fails:** a Nix *syntax* error (`unexpected ')'`) means you deleted one parenthesis too many or too few. `git diff` shows exactly what you changed; the "before" shape above has balanced parentheses by itself, so the "after" must too.

**Commit:**
```bash
git commit -am "refactor(users): drop implicit mainUser group membership; extraUsers only (S6)"
```

> **Heads-up:** `nixlab` loses this implicit access until Part 10 adds it back through the adapter. That is fine; you are not touching `nixlab` or deploying anything until Part 12.

---

## Part 5 — No host metadata, no service registry (seams S2, S4)

All edits are in `stacks/observability.nix`. Find each spot with grep first.

### 5.1 Find the spots

```bash
cd $OBS
grep -n "hostMeta\|allHosts\|hostsMeta\|registry\|tcpFromRegistry\|probes" stacks/observability.nix
```
Expect hits near: the argument list (top), `publicHost`, `access.interfaces` description, the `probes` option block, and the `blackbox` block. If you still see `registryTcpTargets` or `serviceRegistry`, Guide 1 left them; delete them (the replacements below do the job).

### 5.2 Edit A — arguments (top of the module)

Delete the two lines `hostMeta ? {},` and `allHosts ? {}, # M2-REMOVE (S2)` from the module's argument list (the one that begins `{ config, lib, … }:`).

### 5.3 Edit B — `publicHost`

*before:*
```nix
        publicHost = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = hostMeta.address or null;
          description = ''
            Host name or address that links in notifications and the UIs use.
            Defaults to this host's static address from hostsMeta. Set a name here
            (or a `domain` on a service) once nginx fronts it. Null leaves each
            service's own fallback.
          '';
        };
```
*after:*
```nix
        publicHost = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "192.0.2.10";
          description = ''
            Host name or address that links in notifications and the UIs use.
            Set a name here (or a `domain` on a service) once a reverse proxy
            fronts it. Null leaves each service's own fallback.
          '';
        };
```

### 5.4 Edit C — the interfaces description

In `access.interfaces`, replace the description with:
```nix
            description = ''
              Network interfaces on which the services in `expose` are reachable.
              Empty means loopback only. Names must be non-empty; omit interfaces
              the machine does not have.
            '';
```
(This also removes the last mention of `hostMeta`, which the coupling check would flag. It deliberately drops the "never list a Wi-Fi interface" sentence because your fleet doesn't follow it; see §0.3. Guide 3 will decide the policy.)

### 5.5 Edit D — the `probes` block

*before:* the whole `probes = { gateway…; hosts…; tcpFromRegistry…; tcpTargets…; };` block.
*after:* replace the whole block with:
```nix
        probes = {
          gateway = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "192.0.2.1";
            description = "Address (typically the default gateway) to ICMP-probe, or null.";
          };
          icmpTargets = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            example = ["192.0.2.20"];
            description = "Addresses to ICMP-probe in addition to the gateway. This machine's own publicHost is excluded.";
          };
          tcpTargets = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            example = ["127.0.0.1:8123"];
            description = "host:port TCP probe targets for the blackbox exporter.";
          };
        };
```
Also make sure `tcpFromRegistry` no longer appears anywhere (`grep -n tcpFromRegistry stacks/observability.nix` prints nothing).

### 5.6 Edit E — the blackbox wiring

*before:*
```nix
        services.prometheus-nixlab.maintenance.exporters.blackbox = {
          icmpTargets = lib.mkDefault (
            lib.optional (cfg.probes.gateway != null) cfg.probes.gateway
            ++ lib.filter (a: a != (hostMeta.address or ""))
            (map (h: allHosts.${h}.address) cfg.probes.hosts)
          );
          tcpTargets = lib.mkIf cfg.probes.tcpFromRegistry (lib.mkDefault cfg.probes.tcpTargets);
        };
```
*after:*
```nix
        services.prometheus-nixlab.maintenance.exporters.blackbox = {
          icmpTargets = lib.mkDefault (
            lib.optional (cfg.probes.gateway != null) cfg.probes.gateway
            ++ lib.filter (a: a != cfg.publicHost) cfg.probes.icmpTargets
          );
          tcpTargets = lib.mkDefault cfg.probes.tcpTargets;
        };
```
(A `null` publicHost is fine: no string equals `null`, the same outcome as the old `or ""`.)

### 5.7 Check

```bash
nix fmt && git add -A
grep -n "hostMeta\|allHosts\|hostsMeta\|serviceRegistry\|tcpFromRegistry" stacks/observability.nix | wc -l   # must print 0
seams | wc -l
nix build .#checks.x86_64-linux.toplevel-external --no-link --show-trace 2>&1 | grep -m3 error
```
The final command should still fail (sops/Loki-Alloy work remains) but with a **different** error each time you progress; it no longer mentions `hostMeta` or `probes`.

**Commit:**
```bash
git commit -am "refactor(stack): explicit publicHost/gateway/icmp/tcp options; no host metadata (S2, S4)"
```

---

## Part 6 — Fix two boundary problems

Design rule: a service module owns **its own** options, never a sibling's. Your code breaks that twice. Both are safe to fix because no host sets these options (§0.3).

### 6.1 Loki shouldn't own Alloy's settings

Loki declares `enableAlloy`, `alloyPort`, `alloyPackage`, but **never reads them**; only the stack does, to configure Alloy. Alloy already has its own `port` (default 12345) and `package` (default `pkgs.grafana-alloy`), so nothing needs to be added to Alloy.

**Find:**
```bash
grep -rn "alloyPort\|enableAlloy\|alloyPackage" modules stacks sops docs
```
**Do:**

1. **Loki module** (`loki/default.nix`): delete the three option declarations `alloyPackage`, `enableAlloy`, `alloyPort`.
2. **Ports** (`modules/nixos/observability/ports.nix`): in `systm--ports-loki` delete the line `services.loki-nixlab.alloyPort = lib.mkDefault 12345;`. (Alloy's own default is already 12345, so the number is unchanged.)
3. **Stack** (`stacks/observability.nix`): in the `services.alloy-nixlab = { … }` block

   *before:*
   ```nix
          enable = lib.mkDefault svc.loki-nixlab.enableAlloy;
          port = lib.mkDefault svc.loki-nixlab.alloyPort;
          package = lib.mkDefault svc.loki-nixlab.alloyPackage;
   ```
   *after:*
   ```nix
          enable = lib.mkDefault true;
   ```
   and in the Prometheus scrape-job list

   *before:*
   ```nix
        ++ lib.optional svc.loki-nixlab.enableAlloy
        (scrapeJob "alloy" (loopback svc.loki-nixlab.alloyPort))
   ```
   *after:*
   ```nix
        ++ lib.optional svc.alloy-nixlab.enable
        (scrapeJob "alloy" (loopback svc.alloy-nixlab.port))
   ```
   (the surrounding shape may differ slightly; keep your list structure, change only the two reads.)
4. **Compatibility aliases** (so an old setting keeps working for one release). In the stack's `imports = [ … ];` add:
   ```nix
        # Remove in 0.3
        (lib.mkRenamedOptionModule ["services" "loki-nixlab" "alloyPort"] ["services" "alloy-nixlab" "port"])
        (lib.mkRenamedOptionModule ["services" "loki-nixlab" "alloyPackage"] ["services" "alloy-nixlab" "package"])
        (lib.mkRenamedOptionModule ["services" "loki-nixlab" "enableAlloy"] ["services" "alloy-nixlab" "enable"])
   ```
   If the stack has no `imports` list yet, add one inside the module body (`imports = [ … ];` at the same level as `options` and `config`).

### 6.2 One owner for the maintenance log

`services.maintenance-log-nixlab` already has `enable` and `logPath`. Loki has duplicates that the stack copies across.

**Do first (a safety check):** compare the two default paths.
```bash
grep -n "maintenance.jsonl" modules/nixos/observability/loki/default.nix modules/nixos/observability/maintenance-log/default.nix
```
They must be the **same** string. If not, change the maintenance-log default to match **Loki's**.

**Then:**

1. **Loki module:** delete the whole `maintenance = { enable…; logPath…; };` option block **and** its assertion (the `.log` suffix check; the maintenance-log module has the same one).
2. **Stack:** wherever it reads `svc.loki-nixlab.maintenance.enable` or `.logPath`, read `svc.maintenance-log-nixlab.enable` / `.logPath` instead. Find them:
   ```bash
   grep -n "loki-nixlab.maintenance\|loki-nixlab\.maintenance" stacks/observability.nix
   ```
   Then, inside the `services.maintenance-log-nixlab` block:

   *before:*
   ```nix
        enable = lib.mkDefault svc.loki-nixlab.maintenance.enable;
        logPath = lib.mkDefault svc.loki-nixlab.maintenance.logPath;
   ```
   *after:*
   ```nix
        enable = lib.mkDefault cfg.loki.maintenance.enable;
   ```
   and **delete** the line in the Loki block that sets `maintenance.enable = lib.mkDefault cfg.loki.maintenance.enable;` (Loki no longer has that option).
   The stack-level option `services.nixlab-observability.loki.maintenance.enable` **stays**; your `profile-base` uses it.
3. **Aliases** (add to the same `imports` list):
   ```nix
        (lib.mkRenamedOptionModule ["services" "loki-nixlab" "maintenance" "enable"] ["services" "maintenance-log-nixlab" "enable"])
        (lib.mkRenamedOptionModule ["services" "loki-nixlab" "maintenance" "logPath"] ["services" "maintenance-log-nixlab" "logPath"])
   ```

### 6.3 Test the aliases

An alias nobody tests is a promise nobody checks. In `flake/ci/observability-checks.nix`, inside the `hosts = { … };` block add:
```nix
      # An old-style setting must still reach its new home.
      alias = harness.mkTestHost {
        modules = [
          harness.minimalStack
          {services.loki-nixlab.alloyPort = 12999;}
        ];
      };
```
and in the `// { … }` checks add:
```nix
        alias-alloyport = pkgs.runCommand "alias-alloyport" {} ''
          test "${toString hosts.alias.config.services.alloy-nixlab.port}" = "12999"
          touch $out
        '';
```

### 6.4 Check

```bash
nix fmt && git add -A
grep -rn "alloyPort\|enableAlloy\|alloyPackage\|loki-nixlab.maintenance" modules stacks | grep -v mkRenamedOptionModule | wc -l    # must print 0
```
(Only the alias lines may remain, which the `grep -v` hides.)

**Commit:**
```bash
git commit -am "refactor(loki,alloy,maintenance-log): one owner per option; compat aliases"
```

---

## Part 7 — Secrets that don't need sops-nix (seam S5)

### 7.1 Stack: stop touching sops

In `stacks/observability.nix`:

1. In the `imports` list, **replace** the two sops lines with the plain service modules:

   *before:*
   ```nix
        self.nixosModules.nsops--alertmanager
        self.nixosModules.nsops--grafana
   ```
   *after:*
   ```nix
        self.nixosModules.servc--alertmanager-nixlab
        self.nixosModules.servc--grafana-nixlab
   ```
   **Why replace and not just delete:** the stack never imported the Alertmanager and Grafana modules directly. It got them *indirectly*, because each `nsops--*` module imports its service module. Deleting the sops lines alone leaves the stack without those two modules, and evaluation fails with `attribute 'alertmanager-nixlab' missing`. The `nsops--*` modules stay exported; nixlab's adapter will import them in Part 10.
2. **Delete** this line:
   ```nix
        sops.secrets.ALERTMANAGER_ENV.restartUnits = lib.mkIf cfg.notifications.ntfyAuth.enable ["ntfy-provision.service"];
   ```
3. Add a new option next to the other `notifications.ntfyAuth.*` options:
   ```nix
          environmentFile = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = config.services.alertmanager-nixlab.environmentFile;
            defaultText = lib.literalExpression "config.services.alertmanager-nixlab.environmentFile";
            description = ''
              File of KEY=VALUE lines read by ntfy-provision (NTFY_ALERTMANAGER_PASSWORD and friends).
              Defaults to the Alertmanager environment file; both need the same credentials.
            '';
          };
   ```
   (If `notifications.ntfyAuth` is written as nested attributes in your file, put it at that nesting level; the final option path must be `services.nixlab-observability.notifications.ntfyAuth.environmentFile`.)
4. Where the stack previously used `config.sops.secrets.ALERTMANAGER_ENV.path`:

   *before:* `environmentFile = config.sops.secrets.ALERTMANAGER_ENV.path;`
   *after:* `environmentFile = cfg.notifications.ntfyAuth.environmentFile;`
5. Add an assertion in the stack's `assertions = [ … ];` (create the list inside `config` if there isn't one):
   ```nix
          {
            assertion = cfg.notifications.ntfyAuth.enable -> (cfg.notifications.ntfyAuth.environmentFile != null);
            message = "services.nixlab-observability.notifications.ntfyAuth.enable needs notifications.ntfyAuth.environmentFile (it defaults to services.alertmanager-nixlab.environmentFile). Provide a file containing the NTFY_*_PASSWORD variables.";
          }
          {
            assertion = lib.all (i: i != "") cfg.access.interfaces;
            message = "services.nixlab-observability.access.interfaces must not contain empty interface names. Remove interfaces this machine does not have (for example a missing Wi-Fi device) before passing the list.";
          }
   ```
   The second assertion is the interface rule from ADR-008. If your §1.3 note said "yes, there's an empty one", this will fail your real hosts until Part 10.3; that is intended.

### 7.2 The optional sops module keeps the restart rule

"Secret rotated → re-run ntfy-provision" only makes sense for someone using sops, so it belongs in `sops/alertmanager.nix`.

*before:*
```nix
          restartUnits = ["alertmanager.service"];
```
*after:*
```nix
          restartUnits =
            ["alertmanager.service"]
            ++ lib.optional (config.services.ntfy-nixlab.auth.enable or false) "ntfy-provision.service";
```
(`or false` keeps the module valid for someone who imports it without ntfy.)

### 7.2b The sops modules must NOT import the service they wire

**Why:** NixOS recognises "the same module imported twice" by a hidden `key`. Modules that come from flake outputs have no key of their own; their identity depends on *who imported them*. So if `servc--alertmanager-nixlab` is imported by the stack **and** by `nsops--alertmanager`, NixOS loads it twice and fails with `The option … is already declared in …` (same file named twice). It only shows up on machines that use the sops modules (your `stable`/`unstable` harness hosts and nixlab itself), not on `external`.

**Rule from now on:** each module is imported from exactly one place. The stack imports the services; the `nsops--*` modules only add secret wiring on top.

**Do:** in **both** `sops/alertmanager.nix` and `sops/grafana.nix`:

1. Delete the line
   ```nix
       imports = [self.nixosModules.servc--alertmanager-nixlab];     # grafana file: servc--grafana-nixlab
   ```
2. Check whether `self` is still used anywhere else in the file:
   ```bash
   grep -n "self" sops/alertmanager.nix sops/grafana.nix
   ```
   If the **only** hit is the outer `{self, ...}: {` line, change that line back to `{...}: {` (otherwise `deadnix` will complain about an unused argument). This also retires the Guide 1 `self` workaround: these files no longer need `self` at all.
3. Add one comment line at the top of each module, so the next person knows:
   ```nix
   # Optional sops-nix wiring. Import it TOGETHER WITH the service module
   # (or the whole stack, which imports the services). It does not import them itself.
   ```

**Consequence to document:** anyone using `nsops--alertmanager` without the stack must also import `servc--alertmanager-nixlab` themselves. Add that sentence to the nsops row in `docs/architecture/public-api.md`, and one line to ADR-009's Decision item 2: *"They do not import the service modules; the consumer (or the stack) does."*

### 7.3 Check: a machine with no sops-nix builds

```bash
nix fmt && git add -A
nix build .#checks.x86_64-linux.toplevel-external .#checks.x86_64-linux.toplevel-stable --no-link --show-trace 2>&1 | tail -20
```
**Check:** **success** for **both**: no `error:`. `toplevel-external` has no sops-nix; `toplevel-stable` uses the sops modules, which is the one that catches the double-import problem from §7.2b. This is the headline test of the whole guide: a stranger's machine, with **no** special arguments, **no** `nixlab` options and **no** sops-nix, builds the full stack. The first run downloads and builds a lot; be patient.

**If it fails:** read the **first** `error:` line (T4).
- `The option … is already declared in …` with the **same file named twice** → a module is imported from two places (§7.2b). Look for `servc--*` imports inside `sops/*.nix`.
- `attribute 'alertmanager-nixlab' missing` (or `'grafana-nixlab'`) → the stack no longer imports that service module. Make sure Part 7.1 step 1 *replaced* the `nsops--*` imports with `servc--alertmanager-nixlab` and `servc--grafana-nixlab`.
- `option 'sops' does not exist` → something still references `config.sops…` in the stack or a `servc--*` module: `grep -rn "sops" modules stacks`. Only `sops/*.nix` may mention it.
- `The option … services.…secretsFile … is used but not defined` → a `servc--*` module is reading `secretsFile`; only the `nsops--*` modules may.
- `option … probes.icmpTargets … does not exist` → Part 5 edit D wasn't saved.

**Commit:**
```bash
git commit -am "refactor(secrets): stack takes secret paths as options; sops wiring optional (S5)"
```

---

## Part 8 — Runbook URL becomes an option (seam S7)

### 8.1 Find every copy of the URL

```bash
cd $OBS
grep -rn "github.com/Temhr" modules stacks flake
```
Expect hits in `prometheus/_internals/rendered.nix` and probably `prometheus/_internals/maintenance-alerts.nix` (where `prometheusMaintenanceAlerts` supplies its own default; the all-features check calls it without a base URL, so a default must exist there).

### 8.2 Add the option

In the Prometheus module's options (`prometheus/_internals/options.nix`, near `dataDir`/`retention`):
```nix
    runbookBaseUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/Temhr/observability/blob/main/docs/runbooks";
      description = "Base URL that alert `runbook` annotations link to. The alert name and `.md` are appended.";
    };
```
(The default **must be exactly the string currently in `rendered.nix`**; that keeps the output identical.)

### 8.3 Use it

- `rendered.nix`: replace `runbookBase = "https://…";` with `runbookBase = config.services.prometheus-nixlab.runbookBaseUrl;` (`rendered.nix` already receives `config`, as the check calls `prometheusRendered {config = hostConfig; …}`).
- `maintenance-alerts.nix`: **leave its own default string** (it has no host config); it is the same URL.

Now there are two copies of one string, which can drift. Add a guard check to `observability-checks.nix` inside the `// { … }`:
```nix
        runbook-url-consistent = pkgs.runCommand "runbook-url-consistent" {} ''
          test "${hosts.minimal.config.services.prometheus-nixlab.runbookBaseUrl}" = "${(prometheusMaintenanceAlerts {features = allFeatures;}).runbookBase or hosts.minimal.config.services.prometheus-nixlab.runbookBaseUrl}"
          touch $out
        '';
```
> If `prometheusMaintenanceAlerts` does not expose its base URL as an attribute, this check always passes (it falls back to comparing with itself). In that case use this manual check instead and move on:
> `grep -rn "github.com/Temhr" modules | wc -l` must print **2** and both lines must show identical URLs.

### 8.4 Check

```bash
nix fmt && git add -A
nix build .#checks.x86_64-linux.prom-rules-stable .#checks.x86_64-linux.prom-rules-all-features .#checks.x86_64-linux.prom-rule-tests .#checks.x86_64-linux.runbook-coverage --no-link
```
**Commit:** `git commit -am "refactor(prometheus): runbook base URL is an option (S7)"`

---

## Part 9 — Finish the public interface

### 9.1 The example a stranger can copy

Create `examples/minimal/flake.nix`:
```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    observability.url = "github:Temhr/observability";
    observability.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = {
    nixpkgs,
    observability,
    ...
  }: {
    nixosConfigurations.demo = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        observability.nixosModules.stack--observability
        {
          services.nixlab-observability.enable = true;
          services.alertmanager-nixlab.environmentFile = "/run/secrets/alertmanager.env";
          services.grafana-nixlab.credentialsFile = "/run/secrets/grafana-admin";
          services.grafana-nixlab.secretKeyFile = "/run/secrets/grafana-secret-key";
          # A real machine also needs hardware/boot configuration.
          system.stateVersion = "24.11";
          boot.loader.grub.enable = false;
          fileSystems."/" = {
            device = "none";
            fsType = "tmpfs";
          };
        }
      ];
    };
  };
}
```
**Check:**
```bash
git add -A
nix build ./examples/minimal#nixosConfigurations.demo.config.system.build.toplevel \
  --override-input observability "path:$PWD" --no-link
```
Success = no `error:`. (This is the real-world version of the `external` test.)

### 9.2 Finish the docs

1. In `docs/architecture/public-api.md`, add a **Breaking changes in 0.2** table:

   | Change | Replacement | Alias? |
   |---|---|---|
   | The flake no longer reads `nixlabLib`, `hostMeta`, `allHosts`, `config.nixlab.mainUser` | options below | n/a (never public) |
   | `probes.hosts`, `probes.tcpFromRegistry` removed | `probes.icmpTargets`, `probes.tcpTargets` | no |
   | `loki-nixlab.{enableAlloy,alloyPort,alloyPackage}` | `alloy-nixlab.{enable,port,package}` | yes, until 0.3 |
   | `loki-nixlab.maintenance.{enable,logPath}` | `maintenance-log-nixlab.{enable,logPath}` | yes, until 0.3 |
   | The stack no longer imports `nsops--*` | import them yourself | no |
   | `secretsFile` has no default | set it | no |
   | `mainUser` no longer gets implicit access | set `extraUsers` | no |
   | `publicHost`/`probes.gateway` default to `null` | set them | no |
   | New option `prometheus-nixlab.runbookBaseUrl` | | n/a |
   | New option `notifications.ntfyAuth.environmentFile` | | n/a |
   | New assertion: no empty names in `access.interfaces` | | n/a |

2. Create `CHANGELOG.md`:
   ```markdown
   # Changelog

   ## 0.2.0
   ### Breaking
   See the table in docs/architecture/public-api.md.
   ### Added
   - `no-nixlab-coupling` check, `external` and `minimal` harness hosts, `examples/minimal`.
   - Options: `probes.icmpTargets`, `notifications.ntfyAuth.environmentFile`, `prometheus-nixlab.runbookBaseUrl`.

   ## 0.1.0
   Initial extraction from nixlab.
   ```

### 9.3 Final green run

```bash
cd $OBS
git add -A && nix fmt
seams | wc -l                         # must print 0
nix flake check --print-build-logs    # must finish with no error (can take a long time)
```
**Check — all of these must hold:**

1. `seams | wc -l` prints **0**.
2. `nix flake check` passes. If you want it check-by-check instead (clearer progress; each prints nothing when it passes):
   ```bash
   for n in prom-config prom-rules alertmanager-config; do
     for h in stable unstable external; do
       echo "== $n-$h"; nix build ".#checks.x86_64-linux.$n-$h" --no-link --print-build-logs || echo "FAILED: $n-$h"
     done
   done
   for t in toplevel-stable toplevel-external toplevel-minimal no-nixlab-coupling alias-alloyport \
            runbook-coverage dashboard-lint prom-rules-all-features prom-rule-tests \
            maintenance-log-shellcheck pre-commit-check; do
     echo "== $t"; nix build ".#checks.x86_64-linux.$t" --no-link --print-build-logs || echo "FAILED: $t"
   done
   ```
   No line starting `FAILED:`.
3. The example from §9.1 builds.

**If `pre-commit-check` fails:** `nix fmt` then `git add -A` and rerun; `deadnix` failures name a now-unused argument (often `lib` or `config`): delete it from that module's argument list.

**Commit, push, tag:**
```bash
git add -A && git commit -m "docs: public API, changelog, minimal example (0.2)"
git push -u origin decouple
git tag v0.2.0-rc1 && git push origin v0.2.0-rc1
```

---

## Part 10 — Switch nixlab over (the adapter)

Everything so far is in `$OBS`. Now `nixlab` gets the translations the observability flake no longer does.

### 10.1 Point nixlab at the release candidate

```bash
cd $NIXLAB
nix flake lock --override-input observability "github:Temhr/observability/v0.2.0-rc1"
git diff --stat flake.lock         # only the observability entry changed
```

> If your `observability` input is private you can instead use `"git+file://$OBS?ref=decouple"` while developing; commit in `$OBS` first, since only committed changes are seen.

### 10.2 Replace the adapter

**Do:** replace the **entire contents** of `$NIXLAB/stacks/observability-nixlab.nix` with:

```nix
{self, ...}: {
  flake.nixosModules.stack--observability-nixlab = {
    config,
    lib,
    hostMeta ? {},
    ...
  }: let
    registry = self.lib.serviceRegistry {inherit config;};
    registryTcpTargets =
      lib.mapAttrsToList (_: e: "127.0.0.1:${toString e.port}")
      (lib.filterAttrs (k: _: registry.enabled.${k} or false) (registry.endpoints or {}));
    # `or` tolerates a host that does not declare nixlab.mainUser at all.
    mainUsers = let
      u = config.nixlab.mainUser or "";
    in
      lib.optional (u != "") u;
  in {
    imports = [
      self.nixosModules.stack--observability
      # sops wiring is nixlab's choice now. These do NOT import the services; the stack above does.
      self.nixosModules.nsops--alertmanager
      self.nixosModules.nsops--grafana
    ];

    services.nixlab-observability = {
      publicHost = lib.mkDefault (hostMeta.address or null);
      probes.gateway = lib.mkDefault (hostMeta.gateway or null);
      probes.tcpTargets = lib.mkDefault registryTcpTargets;
    };

    # The encrypted files live in this repository.
    services.alertmanager-nixlab.secretsFile = lib.mkDefault ../sops/alertmanager.env;
    services.grafana-nixlab.secretsFile = lib.mkDefault ../sops/grafana.yaml;

    # The group membership the modules used to grant implicitly.
    # Plain assignment on purpose: lists merge; mkDefault would be dropped if a host set its own.
    services.loki-nixlab.extraUsers = mainUsers;
    services.grafana-nixlab.extraUsers = mainUsers;
    services.alloy-nixlab.extraUsers = mainUsers;
    services.ntfy-nixlab.extraUsers = mainUsers;
    services.prometheus-nixlab.extraUsers = mainUsers;
  };
}
```

> **The most important difference from the Guide 1 adapter:** the three-line `imports` list. Guide 1's adapter imported only `stack--observability` and relied on the stack to pull in the sops modules. In v0.2 the stack no longer does, so the adapter must import `nsops--alertmanager` and `nsops--grafana` itself. If you edit the old file instead of replacing it, these two lines are the ones that get missed. Symptom: `The option 'services.alertmanager-nixlab.secretsFile' does not exist`.

Quick self-check before building:
```bash
grep -n "nsops" stacks/observability-nixlab.nix      # must show two lines (alertmanager, grafana)
```

### 10.3 Only if §1.3 found an empty interface name

In `hosts/common/profile-desktop.nix`, add `lib` to the module's arguments (`{config, pkgs, lib, hostMeta ? {}, ...}:`), then:

*before:*
```nix
    services.nixlab-observability.access.interfaces = [hostMeta.ethIface hostMeta.wifiIface];
```
*after:*
```nix
    services.nixlab-observability.access.interfaces =
      lib.filter (i: i != "") [hostMeta.ethIface hostMeta.wifiIface];
```
(If §1.3 found none, **skip this**.)

### 10.4 Check

```bash
git add -A
grep -rnE 'tcpFromRegistry|probes\.hosts|enableAlloy|alloyPort|alloyPackage|loki-nixlab\.maintenance' hosts home modules stacks   # prints nothing
nix flake check
for h in nixnas1 nixnas2 nixace nixsun nixtop nixvat nixzen; do
  nix build ".#nixosConfigurations.$h.config.system.build.toplevel" --no-link || echo "FAILED: $h"
done
```
**Check:** the `grep` prints nothing; `nix flake check` passes; no `FAILED:` lines.

**If it fails:** `error: … defined multiple times` on `publicHost`/`probes.gateway` → a `mkOptionDefault` crept into the adapter; use `lib.mkDefault`. `The option … secretsFile … does not exist` → the adapter does not import `nsops--alertmanager` / `nsops--grafana` (§10.2). `option … secretsFile … used but not defined` → the adapter's two `secretsFile` lines are missing or on the wrong option path. `access.interfaces must not contain empty interface names` → do §10.3.

`nixlab`'s own `flake/nixos-lib.nix` **stays**; other nixlab modules still use it.

**Commit:**
```bash
git commit -am "refactor(observability): adapter owns nixlab-specific wiring"
```

---

## Part 11 — Prove nothing changed (parity)

### 11.1 Take the "after" snapshot from a clean tree

```bash
cd $NIXLAB && git status --short       # must print nothing; commit first if it does
$BASELINE/capture2.sh $BASELINE/after2
```

### 11.2 Compare

```bash
diff -ru $BASELINE/before2 $BASELINE/after2 -x toplevel > $BASELINE/parity2.diff
wc -l $BASELINE/parity2.diff
```
**The goal is an empty (or nearly empty) file.** Anything left must be explained by this table:

| Where | OK? | Note |
|---|---|---|
| any file | **expect no diff** | nothing about the rendered result should change |
| `sops-secrets.json` → `restartUnits` | order only | before it was merged from two modules; now one list. A different *set* of units is a bug. |
| `users.json` / `groups.json` → `extraGroups` | order only | set must be equal |
| `firewall-ifaces.json` | only if you did §10.3 | then **only** the `""` entry disappears |
| `assertion-count.json` | **yes, higher** | by the number of assertions added (about 2). Assertions never change outputs. |
| `units*.json` store-path hashes | possible churn | compare ignoring hashes: `sed -E 's#/nix/store/[a-z0-9]{32}-#/nix/store/#g' file` on both sides; then it must match. A changed `builtins.toFile` name like `loki.json` is a **real** content change. |
| `alertmanager.json`, `loki-ruler.json`, `datasources.json`, `alloy-extra.json`, `prometheus-rendered.json`, `units.json` for Alloy (port/package) | **no** | any diff = a bug in Part 6/7/8 |

### 11.3 Write it up

Create `$OBS/docs/development/migration/parity-report-2.md` listing each remaining diff line and its explanation. Commit it in `$OBS`.

**If something is unexplained:** your Part 3–8 commits are each one logical change, so you can find the culprit by checking out earlier commits of `$OBS` one at a time (`git bisect` is built for this), re-pointing nixlab at each (`--override-input … "git+file://$OBS?ref=<commit>"`), and re-running only the failing file's comparison.

---

## Part 12 — Deploy, then release

### 12.1 Canary on one host

On the canary host (choose a low-risk desktop, **not** `nixnas1`), from branch `obs-decouple`:

```bash
sudo nixos-rebuild test --flake ~/nixlab#nixvat       # activates WITHOUT making it the boot default
```
Then:
```bash
nix run github:Temhr/observability/v0.2.0-rc1#mon-check -- --fire-test    # must exit 0
for u in loki prometheus grafana ntfy alloy; do id $u; done               # UIDs same as before
id <your-username>                                                         # still lists the service groups
ls /data/loki >/dev/null && echo "read access OK"                          # (use your actual data dir)
systemctl --failed                                                         # nothing listed
```
All must match. If so: `sudo nixos-rebuild switch --flake ~/nixlab#nixvat`, **reboot once**, run `mon-check` again.

**Rollback at any time:** `sudo nixos-rebuild switch --rollback`, or choose the previous generation in the boot menu. State on disk is untouched by this guide.

### 12.2 Release

```bash
cd $OBS
git switch main && git merge --no-ff decouple
git tag -a v0.2.0 -m "Decoupled: no nixlab internals; optional sops; explicit interface"
git push origin main v0.2.0

cd $NIXLAB
nix flake lock --override-input observability "github:Temhr/observability/v0.2.0"
# also change the url in flake.nix from .../v0.1.0 to .../v0.2.0 so it stays pinned:
sed -i 's#observability/v0.1.0"#observability/v0.2.0"#' flake.nix
git add -A && git commit -m "chore(observability): pin to v0.2.0"
```
Then re-run §10.4's checks once more.

### 12.3 Roll out safely

> Your hosts auto-update from `main` (Guide 1 §7.1). **Do not merge `obs-decouple` into nixlab's `main` until the canary has soaked.**

1. Canary host: at least 3 days, including one backup run, one alert, one reboot.
2. A host on the other nixpkgs channel.
3. `nixnas1` last (ZFS, `/mirror`).
4. Merge to `main`; let the rest auto-upgrade.
5. Soak for a week with no regressions.

---

## Exit criteria

- [ ] `seams | wc -l` is **0**; `no-nixlab-coupling` is in CI and green.
- [ ] `toplevel-external` (no sops-nix, no special args) builds; `examples/minimal` builds.
- [ ] `nix flake check` green in **both** repos; all seven nixlab hosts build.
- [ ] `parity2.diff` fully explained and written up.
- [ ] Canary passed (`mon-check --fire-test`, UIDs unchanged, your user still has read access, survived a reboot); all hosts migrated; a week of soak.
- [ ] `public-api.md`, five ADRs, `CHANGELOG.md` committed; `v0.2.0` tagged; nixlab pinned to it.
- [ ] No real `M2-REMOVE` markers remain. Two kinds of hit are **expected and fine** because they are text *about* the marker, not markers:
  - in `$OBS`: the coupling guard's own search pattern in `flake/ci/observability-checks.nix`;
  - in `$NIXLAB`: the guides you committed under `docs/migration/`.

  Use these commands, which skip them; both must print nothing:
  ```bash
  cd $OBS    && git grep -n M2-REMOVE -- . ':!flake/ci/observability-checks.nix' ':!docs'
  cd $NIXLAB && git grep -n M2-REMOVE -- . ':!docs/migration'
  ```

## Hand-off to Guide 3 (deliberately not done here)

1. Rename modules/options and flatten directories (with aliases).
2. Fold the port modules into the services (ports are currently triplicated).
3. **Decide the Wi-Fi exposure policy** (§0.3): the docs and `profile-desktop` disagree.
4. Loki hard-codes the `{job="maintenance-log"}` label that Alloy produces; give it an extension point.
5. `/var/lib/private/alertmanager` and `/var/lib/node_exporter` are hard-coded in the stack.
6. nginx/firewall side effects when `domain` is set aren't in the public contract.
7. Loki-ruler alerts have no tests and aren't covered by the runbook check; Loki/Alloy config isn't validated in CI.
8. Hermetic scripts; split and scrub `docs/wiki/observability.md` (it contains LAN details).
9. Hardening review, backup/restore drills, secret-rotation automation, release automation.
10. **README for both repos**, after Guide 3 as you asked. `docs/architecture/public-api.md` is its main source.

## Appendix — Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `error: path '…' does not exist` for a file you just made | You forgot `git add -A` (T7). |
| `undefined variable 'self'` | The module's outer line is still `{...}:`; make it `{self, ...}:`. |
| `attribute 'obsLib' missing` | `flake/lib/obs-lib.nix` still registers `nixlabLib`, or a module lacks `obsLib = self.lib.obsLib;`. |
| `called without required argument 'obsLib'` | A `_internals` caller didn't pass `obsLib` down. |
| `option … is already declared in …` (same file twice) | One module imported from two places; delete the extra import (§7.2b). |
| `option 'sops' does not exist` | Something outside `sops/*.nix` still refers to `config.sops…` (Part 7). |
| `defined multiple times` for `publicHost`/`probes.gateway` | Used `mkOptionDefault` in the adapter. Use `mkDefault`. |
| `access.interfaces must not contain empty interface names` | See §10.3. |
| `The option 'services.loki-nixlab.alloyPort' does not exist` | The alias is missing (Part 6), or a host still sets it. |
| Your user can't read `/data/*` on the canary | The adapter's `extraUsers` lines are missing (§10.2). |
| `no-nixlab-coupling` fails listing ordinary `obsLib` lines | The Part 3.2 sed rewrote the guard's own pattern from `nixlabLib` to `obsLib`. Fix it as in §3.2b. (`seams` still says 0 because it lives in `~/obs-env.sh`.) |
| `deadnix` fails | Delete the now-unused argument it names. |
| Sops restart list differs only in order | Fine; record it (§11.2). |
| `nix flake check` passes locally but the host can't fetch the tag | Tag not pushed, or private-repo `access-tokens` missing on that host. |
| Completely stuck | `git stash` your edits, run the last passing **Check**, then re-apply one Edit at a time. |
