# Observability Flake — Guide 3 of 3: Evolution

> **Goal:** turn the decoupled flake (v0.2.0) into a product other people could use: neutral names, a flat layout, one owner for every setting, stronger tests (including a real VM boot), generated and scrubbed docs, release automation, and READMEs for both repos. Policy changes (Wi-Fi exposure, hardening, secret rotation) come **last and one at a time**, because they are the only steps meant to change what your hosts do.
>
> **Order of work:** safety net first (Part 2), then structure (Parts 3–9), then ship and prove parity (Part 10), then deliberate behaviour changes (Part 11), then READMEs (Part 12).
>
> **Revision 3.** Rewritten after reading the real code you sent (now including the ntfy, Prometheus-internals, Grafana, Alertmanager and sops modules, both dashboards, the maintenance logger, `ports.nix`, `_todo.txt`, `nixvat.nix` and `hosts-meta.nix`), on top of the first batch: the stack, Loki, Alloy, maintenance-log, host-exporters and backup modules, `obs-lib`, the harness and checks, the three scripts, ADR-003/005/006/008/009, the wiki, both READMEs, nixlab's adapter, profiles, `flake.nix`, the three automation modules and `capture2.sh`. Steps are now exact edits wherever I could see the file. Files I still haven't seen are listed in Appendix C. Nothing has been run against your tree, so every step still ends in a **Check**; trust the Check over this text.

---

## What reading your code changed

| Finding | Effect on this guide |
|---|---|
| **ADR-003** keeps the `servc--/systm--/stack--/nsops--` prefixes and leaves generic vs product-scoped names open. | The rename map keeps the prefixes and is product-scoped; a superseding **ADR-010** is part of Part 5. Wi-Fi policy becomes **ADR-011**. |
| The nixlab adapter you sent is the **Guide 1** version (no `publicHost`, `probes.gateway`, `extraUsers`). | New **§1.2** checks whether the fleet lost those on v0.2.0 and fixes it before any baseline is taken. |
| Your automation: `flake-update` runs `nix flake update` on every host nightly and pushes; `nixlab-gpull` pulls hourly; `nixos-upgrade` builds `main` at 02:00 and **reboots**. | New **§10.0**: canary from a separate checkout with three `mkForce` pins; edit `flake.nix`, never rely on `--override-input`; merging to `main` rolls the whole fleet in one night. |
| `profile-base` sets `ntfyAuth.enable = false` yet exposes ntfy and Prometheus; desktops add Wi-Fi. | §11.1 is stronger: unauthenticated services are reachable on Wi-Fi. |
| Loki and Alloy build their configs inline; the Loki job label is hard-coded in the stack **and** in Loki. | §2.3 and §3.4 are now exact edits. |
| The four Loki-ruler alerts have no runbook files in your list. | §2.2 will be red until you write them (or list them in `_todo.txt`). |
| The wiki is stale in many places and references files that don't exist; the observability README is HTML inside Markdown with eight dead links. | Part 7 has a statement-by-statement fix table; Part 12 replaces the README. |
| `mon-check.sh` & co. use specific tools and shellcheck-unfriendly patterns. | Part 6 lists the exact findings and fixes. |
| **A latent v0.2.0 bug:** `alloy/default.nix` and `prometheus/_internals/config.nix` use `cfg.group`, an option neither module declares, so setting `extraUsers` on them fails evaluation (the harness never sets it). | New **§1.2** ships a **v0.2.1** hotfix, test first, *before* nixlab's adapter can be restored. |
| `ports.nix` and the option defaults already agree on every number. | §3.2 needs no default edits. |
| Six ZFS alerts need custom `zfs_*` metrics that only nixlab's own scripts produce; the Timers panel hard-codes nixlab's timer names; two Loki panels hard-code the maintenance label. | §8.2 and §8.3. |
| `docs/runbooks/_todo.txt` is empty. | §2.2 is certainly red until four runbooks exist. |
| Every nixlab host has an `ethIface`; only `nixnas1` has no Wi-Fi. `nixvat` is a QEMU guest. | §11.1: wired-only is feasible everywhere; §10.0 uses `nixvat` as the canary. |

---

## How to read this guide

Same shape as Guide 2: **Where / Do / Check / If it fails / Commit**. The toolbox (T1–T8: run one check, list checks, run all, read an error, find a line, edit safely, `git add -A` before every `nix` command, undo) is unchanged; see Guide 2 §0.6.

### Plan at a glance

| Part | What you do | Repo | Changes host behaviour? |
|---|---|---|---|
| 1 | **Fix the v0.2.1 bug, reconcile the adapter**, branch, snapshot "before" | both | yes, once: the hotfix and the restored adapter |
| 2 | **Safety net:** tests that pin today's behaviour (all must be green *now*) | `$OBS` | no |
| 3 | One owner per setting: ports, paths, Loki job label | `$OBS` | no |
| 4 | Stable module keys (importing twice becomes harmless) | `$OBS` | no |
| 5 | Rename + flatten, with generated compatibility aliases | `$OBS` | no |
| 6 | Hermetic scripts | `$OBS` | no |
| 7 | Docs: split, scrub LAN data, generate the options reference | `$OBS` | no |
| 8 | Gate nixlab-specific content behind options | `$OBS`, adapter | no |
| 9 | CI and release automation | `$OBS` | no |
| 10 | Release v0.3.0; nixlab adopts it in two stages; parity | both | no |
| 11 | **Policy changes**, one per commit, each canaried | both | **yes, deliberately** |
| 12 | READMEs (both repos) | both | no |
| 13 | What "1.0" means; removing compatibility | `$OBS` | no |

---

## 0. Background (read once)

### 0.1 Entry gate

Do not start until **all** are true:

- [ ] Guide 2's exit criteria are ticked: all hosts on `v0.2.0`, a week of soak, `parity-report-2.md` committed.
- [ ] `nixlab` `main` pins `observability/v0.2.0` (§1.2 moves it to `v0.2.1`); both repos' `main` are clean and `nix flake check` is green in both.
- [ ] Both of these print nothing:
  ```bash
  cd $OBS    && git grep -n M2-REMOVE -- . ':!flake/ci/observability-checks.nix' ':!docs'
  cd $NIXLAB && git grep -n M2-REMOVE -- . ':!docs/migration'
  ```
- [ ] **Housekeeping I noticed in your file list:** `$OBS` shows no `LICENSE` and no `.gitignore` (Guide 1 Part 2/§3.6 asked for both), and `$NIXLAB/docs/migration/` contains only `obs-01-extraction.md`. Fix now:
  ```bash
  ls $OBS/LICENSE* $OBS/.gitignore                    # if either is missing, create it (Guide 1 §3.6)
  cp /path/to/guide-2-decoupling.md /path/to/guide-3-evolution.md $NIXLAB/docs/migration/   # name them obs-02-…, obs-03-…
  ```

### 0.2 Release plan (expand / contract)

Renames are done in two releases so nothing breaks at any point: **expand** (new names *and* old names work) then **contract** (old names removed).

| Release | Contents | Hosts see |
|---|---|---|
| `v0.3.0-rcN` | Parts 2–9 | nothing (parity) |
| `v0.3.0` | same, final | nixlab **Stage A**: bump plus three adapter lines (Part 8), old names via aliases → parity |
| nixlab **Stage B** | nixlab switches to the new names | nothing (store paths identical) |
| `v0.3.x` | Part 11 policy items, one release each | each item, deliberately |
| `v0.4.0` | delete `compat/` (Part 13) | nothing, once nixlab is on new names |
| `v1.0.0` | stability promise | — |

### 0.3 Decisions made for you

| # | Decision | Why |
|---|---|---|
| E1 | **Characterization tests before refactoring.** Part 2 tests describe what the code does *today*; they must pass immediately. A red one means you found a pre-existing bug. | Guide 2 wrote tests that failed on purpose. These are the opposite: a net under the refactor. |
| E2 | **State compatibility is sacred.** Only *option names, module names and file paths* change. Unit names, users/UIDs, data directories, ports, generated file contents do not. | Parity (Part 10) proves it. A rename must never move data. |
| E3 | **Option aliases are generated per leaf option**, never for a whole namespace. | A whole-namespace alias (`mkAliasOptionModule` on `services.old`) has no option type, so definitions from different files can be merged *shallowly*. Your fleet sets `services.nixlab-observability.prometheus.…` from more than one file, and one could silently clobber the other. I can't prove that on your tree, so the safe choice is to avoid the construct. Per-leaf `mkRenamedOptionModule` has proper types and keeps `mkDefault`/`mkForce` priorities. |
| E4 | **Every public module gets a stable `key`.** | Guide 2 §7.2b had to forbid importing a module from two places. With a key, NixOS imports it once however it is reached, which is what a consumer expects. |
| E5 | **Structure and policy never share a release.** | If parity breaks you must know which kind of change did it. |
| E6 | **Gate nixlab-specific content behind options; the nixlab adapter turns each on**, preserving today's behaviour. Narrowing is a Part 11 decision. | Same reason. |
| E7 | **Generate docs that can be generated** (options reference) and check them for drift. | Hand-written option tables rot. |
| E8 | **The rename map is data** (one TSV file) and a script applies it to both repos. | You will run the same rename twice (obs, then nixlab). |
| E9 | **Decisions go through an ADR** (ADR-010 names, ADR-011 exposure). | ADR-003 requires a superseding ADR for the final names; your ADR index reserves 010–012 for this guide. |

### 0.4 Environment additions

Append to `~/obs-env.sh`:

```bash
export MAP=$OBS/docs/development/migration/rename-map.txt   # created in Part 5
# Lines still using pre-0.3 names (outside compat/ and docs/). Goal after Part 5: 0 unexplained lines.
legacy() {
  (cd "$OBS" && grep -rEn '(-nixlab\b|nixlab-observability|nsops--(alertmanager|grafana)\b)' \
    modules stacks sops flake examples)
}
# Fast obs-only parity: fingerprint of the harness hosts (defined in Part 2.6). Run on a clean, committed tree.
fp() {  # usage: fp <outdir>
  rm -rf "$1" && mkdir -p "$1" \
  && (cd "$OBS" && nix build .#packages.x86_64-linux.fingerprint -o /tmp/obs-fp) \
  && cp -rL /tmp/obs-fp/. "$1/" && chmod -R u+w "$1" \
  && sed -i -E 's#/nix/store/[a-z0-9]{32}-#/nix/store/#g' "$1"/*.json
}
```

---

## Part 1 — Fix, reconcile, snapshot

### 1.1 Order of operations

1. **§1.2 first, on `main` of both repos.** It is a hotfix; deploy and soak it like any change (use the canary recipe in §10.0).
2. **Only then** create the branches and take the baseline (§1.3). A baseline taken before the fix would encode the bug.

> Read §10.0 before deploying anything from a branch: your automation will touch the checkout.

### 1.2 A latent v0.2.0 bug, and the nixlab adapter

**The bug.** Guide 2 §10.2 had the adapter set `extraUsers` on five services. Reading the modules: `alloy/default.nix` and `prometheus/_internals/config.nix` both contain `extraGroups = [cfg.group]`, but **neither module declares a `group` option** (Loki, Grafana and ntfy do). Setting `extraUsers` on Alloy or Prometheus therefore fails evaluation with *attribute 'group' missing*. CI was green because the harness never sets `extraUsers`.

**Your adapter.** The `stacks/observability-nixlab.nix` you sent is the **Guide 1** version: it imports the stack and sops modules and sets `tcpTargets` and `secretsFile`, but not `publicHost`, `probes.gateway` or `extraUsers` (Guide 2 §10.2). That is consistent with the bug (the full adapter could not have evaluated). On v0.2.0 the fleet therefore currently has **no gateway ICMP probe, no `externalUrl`/click links in notifications, and your main user is not in the service groups** (no read access to `/data/loki` etc.). Confirm on a host:
```bash
id temhr | tr ',' '\n' | grep -E 'loki|prometheus|grafana|ntfy|alloy'     # you will see none, or fewer than five
grep -c 'blackbox-icmp' /data/prometheus/prometheus.yml                     # 0 if the gateway probe is missing
```

**Step 1: failing test (observability repo, branch off `main`).** In `flake/ci/_harness/default.nix`, add these lines at the top level of `fullStack` (before `services.nixlab-observability = {…}`):
```nix
    users.users.testuser.isNormalUser = true;
    services.loki-nixlab.extraUsers = ["testuser"];
    services.grafana-nixlab.extraUsers = ["testuser"];
    services.alloy-nixlab.extraUsers = ["testuser"];
    services.ntfy-nixlab.extraUsers = ["testuser"];
    services.prometheus-nixlab.extraUsers = ["testuser"];
```
```bash
cd $OBS && git switch main && git pull && git switch -c fix-extrausers
git add -A && nix build .#checks.x86_64-linux.toplevel-stable --no-link 2>&1 | grep -m2 -i "group"
```
**Check (success = failure):** `attribute 'group' missing`.

**Step 2: fix.** Two one-line edits:
```nix
# modules/nixos/observability/alloy/default.nix
-        ++ map (u: {${u} = {extraGroups = [cfg.group];};}) cfg.extraUsers
+        ++ map (u: {${u} = {extraGroups = ["alloy"];};}) cfg.extraUsers
# modules/nixos/observability/prometheus/_internals/config.nix
-      ++ map (u: {${u} = {extraGroups = [cfg.group];};}) cfg.extraUsers
+      ++ map (u: {${u} = {extraGroups = ["prometheus"];};}) cfg.extraUsers
```
**Step 3:** `nix flake check` green. Add to `CHANGELOG.md`: `## 0.2.1` / `### Fixed` / `- extraUsers on alloy-nixlab and prometheus-nixlab failed evaluation (referenced an undeclared group option).` Then merge to `main` and `git tag v0.2.1 && git push origin main v0.2.1`. (The new harness lines stay: they are now a permanent regression test.)

**Step 4: nixlab.**
```bash
cd $NIXLAB && git switch main && git pull && git switch -c fix-adapter
sed -i 's#observability/v0.2.0"#observability/v0.2.1"#' flake.nix && nix flake update observability
```
Replace `stacks/observability-nixlab.nix` with the complete v0.2 adapter:
```nix
{self, ...}: {
  flake.nixosModules.stack--observability-nixlab = {config, lib, hostMeta ? {}, ...}: let
    registry = self.lib.serviceRegistry {inherit config;};
    registryTcpTargets =
      lib.mapAttrsToList (_: e: "127.0.0.1:${toString e.port}")
      (lib.filterAttrs (k: _: registry.enabled.${k} or false) (registry.endpoints or {}));
    mainUsers = let u = config.nixlab.mainUser or ""; in lib.optional (u != "") u;
  in {
    imports = [
      self.nixosModules.stack--observability
      self.nixosModules.nsops--alertmanager
      self.nixosModules.nsops--grafana
    ];
    services.nixlab-observability = {
      publicHost = lib.mkDefault (hostMeta.address or null);
      probes.gateway = lib.mkDefault (hostMeta.gateway or null);
      probes.tcpTargets = lib.mkDefault registryTcpTargets;
    };
    services.alertmanager-nixlab.secretsFile = lib.mkDefault ../sops/alertmanager.env;
    services.grafana-nixlab.secretsFile = lib.mkDefault ../sops/grafana.yaml;
    # Plain assignment on purpose: lists merge; mkDefault would be dropped if a host set its own.
    services.loki-nixlab.extraUsers = mainUsers;
    services.grafana-nixlab.extraUsers = mainUsers;
    services.alloy-nixlab.extraUsers = mainUsers;
    services.ntfy-nixlab.extraUsers = mainUsers;
    services.prometheus-nixlab.extraUsers = mainUsers;
  };
}
```
(`hostMeta.gateway`: `hosts-meta.nix` defines no `gateway` field, so `mkHostMeta` must supply one or `probes.gateway` stays `null`; check `flake/builders/hosts.nix`/`mkHostMeta` and compare with `$BASELINE/before2/*/prometheus-rendered.json`, which shows what the gateway target used to be.)
```bash
git add -A && nix flake check
```
Deploy it through the normal path **using §10.0's canary recipe**, merge, and let it soak ≥ 3 days. On a host afterwards: `id temhr` lists the five groups, `grep -c blackbox-icmp /data/prometheus/prometheus.yml` is > 0 (if you have a gateway), and `nix run github:Temhr/observability/v0.2.1#mon-check`… (hermetic from 0.3; until then `bin/mon-check.sh`) passes.
**Commit:** `fix(observability): restore publicHost, gateway and extraUsers in the adapter; pin v0.2.1`

### 1.3 Branches, tag, snapshot

```bash
cd $OBS    && git switch main && git pull && git switch -c evolve
cd $NIXLAB && git switch main && git pull && git tag pre-obs-evolve && git switch -c obs-evolve
```
Snapshot with `capture2.sh` unchanged (names are still the old ones):
```bash
cd $NIXLAB
git worktree add /tmp/nixlab-before pre-obs-evolve
(cd /tmp/nixlab-before && bash $BASELINE/capture2.sh $BASELINE/before3)
for h in nixnas1 nixnas2 nixace nixsun nixtop nixvat nixzen; do
  (cd /tmp/nixlab-before && nix eval --raw ".#nixosConfigurations.$h.config.system.build.toplevel.outPath"); echo
done > $BASELINE/outpaths-before.txt
git worktree remove /tmp/nixlab-before
```
**Check:** `git -C $OBS branch --show-current` → `evolve`; `find $BASELINE/before3 -name '*.json' -size 0` prints nothing; `wc -l $BASELINE/outpaths-before.txt` prints 7.
`capture2.sh` reads `services.loki-nixlab…`, `grafana-nixlab…`, `alloy-nixlab…`; in v0.3 those still **read** correctly through the compat aliases, so it keeps working through Stage B and stops working in v0.4.0 (Part 13).
No commit needed.

---

## Part 2 — The safety net (green on day one)

All edits are in `$OBS`. These tests describe today's behaviour. **If one is red, stop and read why before going on**; it is either a real pre-existing problem or a wrong assumption in the test.

All snippets go inside the `// { … }` checks block of `flake/ci/observability-checks.nix`, next to `no-nixlab-coupling`, unless stated. They use the existing `hosts`, `toJson`, `self`, `lib` bindings.

### 2.1 Pin the port numbers

Part 3 deletes `ports.nix`; this test proves no number moves. Values come from Guide 1 §3.4.

```nix
        port-defaults = let
          s = hosts.minimal.config.services;
          got = {
            ntfy = s.ntfy-nixlab.port;
            loki = s.loki-nixlab.port;
            lokiGrpc = s.loki-nixlab.grpcPort;
            grafana = s.grafana-nixlab.port;
            prometheus = s.prometheus-nixlab.port;
            blackbox = s.prometheus-nixlab.blackboxPort;
            smartctl = s.prometheus-nixlab.smartctlPort;
            systemdExporter = s.prometheus-nixlab.systemdExporterPort;
            alertmanager = s.alertmanager-nixlab.port;
            alertmanagerCluster = s.alertmanager-nixlab.clusterPort;
            alloy = s.alloy-nixlab.port;
          };
          want = {
            ntfy = 2586;
            loki = 3100;
            lokiGrpc = 9096;
            grafana = 3101;
            prometheus = 9090;
            blackbox = 9115;
            smartctl = 9633;
            systemdExporter = 9558;
            alertmanager = 9093;
            alertmanagerCluster = 9094;
            alloy = 12345;
          };
        in
          pkgs.runCommand "port-defaults" {} ''
            if [ '${builtins.toJSON got}' != '${builtins.toJSON want}' ]; then
              echo "port defaults changed"
              echo 'got:  ${builtins.toJSON got}'
              echo 'want: ${builtins.toJSON want}'
              exit 1
            fi
            touch $out
          '';
```
**Check:** `git add -A && nix build .#checks.x86_64-linux.port-defaults --no-link --print-build-logs` passes.
**If it fails:** an attribute is missing → that option has another name in your tree (`grep -rn "Port" modules/nixos/observability/*/default.nix`); fix the **test**.

### 2.2 Loki-ruler alerts must have runbooks

Appendix B of Guide 1 noted that the four Loki alerts (`JournalOOMKill`, `KernelFilesystemError`, `NvidiaXid`, `SSHAuthFailureBurst`) are outside the runbook check. This catches *all* ruler alerts without assuming the group structure (`jq` finds every `alert` key anywhere):

```nix
        loki-runbook-coverage = pkgs.runCommand "loki-runbook-coverage" {nativeBuildInputs = [pkgs.jq];} ''
          jq -r '[.. | objects | .alert? // empty] | unique[]' \
            ${toJson "loki-groups.json" hosts.stable.config.services.loki-nixlab.ruler.groups} > alerts.txt
          [ -s alerts.txt ] || { echo "found no Loki alerts: did the structure change?"; exit 1; }
          missing=0
          for a in $(cat alerts.txt); do
            if [ ! -f ${self}/docs/runbooks/$a.md ] && ! grep -qx "$a" ${self}/docs/runbooks/_todo.txt; then
              echo "no runbook for Loki alert $a"; missing=1
            fi
          done
          [ $missing = 0 ]
          touch $out
        '';
```
**Check:** passes. **This will be red:** your file list has no `JournalOOMKill.md`, `KernelFilesystemError.md`, `NvidiaXid.md` or `SSHAuthFailureBurst.md`, and `docs/runbooks/_todo.txt` is empty, so it lists all four. **Write the runbooks now** (copy `docs/runbooks/_template.md` to `docs/runbooks/<Alert>.md`; each needs what fires it, how to confirm, first actions). Adding names to `_todo.txt` is allowed but is exactly the debt this guide exists to retire.

### 2.3 Validate the Loki and Alloy configs

Today CI validates Prometheus and Alertmanager only. Loki's config is built *inside* `preStart` (`lokiConfig`) and Alloy's inside the module's `let` (`baseAlloyConfig`, `configFile`), so CI can't see either. Move each expression out **unchanged** and register it the way Prometheus does (`flake.lib.prometheusRendered`).

**Loki.** Create `modules/nixos/observability/loki/_internals/rendered.nix`. Its body is the whole right-hand side of `lokiConfig =` (from `{ auth_enabled = false; …` through the closing `lib.optionalAttrs cfg.ruler.enable { ruler = {…}; }`), as a function:
```nix
{cfg, lib}:
{
  auth_enabled = false;
  # … exactly what is in loki/default.nix today …
}
// lib.optionalAttrs cfg.ruler.enable {
  ruler = {…};
}
```
In `loki/default.nix` the line becomes `lokiConfig = import ./_internals/rendered.nix {inherit cfg lib;};`, and next to the module registration add:
```nix
{self, ...}: {
  flake.lib.lokiRendered = {config, lib}:
    import ./_internals/rendered.nix {cfg = config.services.loki-nixlab; inherit lib;};
  flake.nixosModules.servc--loki-nixlab = …   # unchanged
}
```
**Alloy.** Create `alloy/_internals/rendered.nix` containing the `baseAlloyConfig` string as `{cfg, hostName}: '' … ''`, replacing `${config.networking.hostName}` by `${hostName}` (three places: the journal source's `labels`, the `systemd` process stage and the `varlogs` process stage). In `alloy/default.nix`: `baseAlloyConfig = import ./_internals/rendered.nix {inherit cfg; hostName = config.networking.hostName;};` and register:
```nix
  flake.lib.alloyRendered = {config, ...}: let
    cfg = config.services.alloy-nixlab;
  in
    (import ./_internals/rendered.nix {inherit cfg; hostName = config.networking.hostName;}) + cfg.extraConfig;
```
Then add the checks:
```nix
        loki-config = pkgs.runCommand "loki-config" {nativeBuildInputs = [pkgs.grafana-loki pkgs.remarshal];} ''
          remarshal -i ${toJson "loki.json" (self.lib.lokiRendered {config = hosts.stable.config; lib = pkgs.lib;})} -if json -of yaml -o loki.yml
          loki -config.file=loki.yml -verify-config
          touch $out
        '';
        alloy-config = pkgs.runCommand "alloy-config" {nativeBuildInputs = [pkgs.grafana-alloy];} ''
          cp ${pkgs.writeText "config.alloy" (self.lib.alloyRendered {config = hosts.stable.config; lib = pkgs.lib;})} config.alloy
          alloy fmt config.alloy > /dev/null      # parses the file; non-zero exit on a syntax error
          touch $out
        '';
```
(`hosts.stable` has the maintenance pipeline enabled, so the appended Alloy section is validated too.) `alloy fmt` is the safe syntax gate; if `nix run nixpkgs#grafana-alloy -- --help` also lists `validate`, add it as a second step.

**Check:** both build. **Prove they can fail:** temporarily delete a closing `}` in the Alloy text, see red, revert. Because this is a pure move, `nix build .#checks.x86_64-linux.toplevel-stable --no-link` must still pass and the fingerprint (§2.6) must not change.
**If Loki complains about a path or `${…}`:** `-verify-config` should not touch the disk; the message names the key (an env placeholder needs `-config.expand-env=true`).

### 2.4 Pin the nginx/firewall side effects (golden file)

Guide 1 Appendix B #5: five modules switch on nginx and open firewall ports when `domain` is set. That is public behaviour nobody has recorded. A *golden file* records it; the check fails if it ever changes unnoticed.

1. Add a harness host with domains set. In `observability-checks.nix`, inside `hosts = { … };`:
   ```nix
      domain = harness.mkTestHost {
        modules = [
          harness.minimalStack
          {
            # All five service modules declare `domain`. openFirewall = true makes the golden capture the 80/443 rules too.
            services.nixlab-observability.openFirewall = true;
            services.loki-nixlab.domain = "loki.example.test";
            services.prometheus-nixlab.domain = "prometheus.example.test";
            services.alertmanager-nixlab.domain = "alertmanager.example.test";
            services.grafana-nixlab.domain = "grafana.example.test";
            services.ntfy-nixlab.domain = "ntfy.example.test";
          }
        ];
      };
   ```
2. Define what is recorded, and a package that writes it (inside the `let`, and in the `perSystem` attrset):
   ```nix
    domainEffects = let c = hosts.domain.config; in {
      nginxEnabled = c.services.nginx.enable;
      vhosts = builtins.attrNames c.services.nginx.virtualHosts;
      firewallTcp = c.networking.firewall.allowedTCPPorts;
      failingAssertions = map (a: a.message) (lib.filter (a: !a.assertion) c.assertions);
    };
   ```
   ```nix
    packages.goldens = pkgs.linkFarm "goldens" [
      {name = "domain-effects.json"; path = toJson "domain-effects.json" domainEffects;}
    ];
   ```
   and the check:
   ```nix
        golden-domain-effects = pkgs.runCommand "golden-domain-effects" {nativeBuildInputs = [pkgs.jq pkgs.diffutils];} ''
          jq -S . ${toJson "got.json" domainEffects} > got.json
          jq -S . ${./_golden}/domain-effects.json > want.json
          diff -u want.json got.json || { echo "side effects changed; if intended: nix build .#goldens -o /tmp/g && cp -L /tmp/g/*.json flake/ci/_golden/"; exit 1; }
          touch $out
        '';
   ```
3. Create the first golden:
   ```bash
   mkdir -p flake/ci/_golden && git add -A
   nix build .#goldens -o /tmp/g && cp -L /tmp/g/domain-effects.json flake/ci/_golden/ && git add -A
   cat flake/ci/_golden/domain-effects.json
   ```
**Check:** the JSON shows `nginxEnabled: true` and your two vhosts. **Read `failingAssertions`:** if it is non-empty the harness is missing something (for example an SSL setting); add it to the `domain` host until it is `[]`, then regenerate. (`_golden/` starts with `_`, so import-tree ignores it.)

### 2.5 The VM smoke test (the one real boot)

Eval-time checks can't catch "starts, then crashes". Create `flake/ci/vm-smoke.nix`:

```nix
{self, ...}: {
  perSystem = {pkgs, system, ...}: {
    # A package, not a check: `nix flake check` should not need KVM. CI runs it explicitly (Part 9).
    packages = pkgs.lib.optionalAttrs (system == "x86_64-linux") {
      vm-smoke = pkgs.testers.runNixOSTest {
        name = "observability-smoke";
        nodes.machine = {...}: {
          imports = [self.nixosModules.stack--observability];
          services.nixlab-observability.enable = true;
          virtualisation.memorySize = 4096;
          virtualisation.diskSize = 4096;
        };
        testScript = ''
          machine.start()
          machine.wait_for_unit("multi-user.target")
          for unit in ["prometheus", "loki", "grafana", "alertmanager", "ntfy", "alloy"]:
              machine.wait_for_unit(unit + ".service")
          machine.wait_until_succeeds("curl -sf http://127.0.0.1:9090/-/ready")
          machine.wait_until_succeeds("curl -sf http://127.0.0.1:3100/ready")
          machine.wait_until_succeeds("curl -sf http://127.0.0.1:3101/api/health")
          machine.wait_until_succeeds("curl -sf http://127.0.0.1:9093/-/ready")
          machine.wait_until_succeeds("curl -sf http://127.0.0.1:2586/v1/health")
          machine.wait_until_succeeds("curl -sf http://127.0.0.1:12345/-/ready")
          # at least one target scraped, and none down
          machine.wait_until_succeeds("curl -sf 'http://127.0.0.1:9090/api/v1/query?query=count(up)' | grep -q '\"value\"'")
          machine.wait_until_succeeds("curl -sf 'http://127.0.0.1:9090/api/v1/query?query=count(up==0)' | grep -q '\"result\":\\[\\]'")
          machine.succeed("test $(systemctl --failed --no-legend | wc -l) -eq 0")
        '';
      };
    };
  };
}
```
Unit names come from your Guide 1 capture list (`prometheus loki alloy grafana alertmanager ntfy`); if a `wait_for_unit` says a unit doesn't exist, use the real name from `$BASELINE/before3/nixvat/units.json`.

**Check** (needs KVM; on NixOS your user needs the `kvm` group):
```bash
git add -A
nix build .#packages.x86_64-linux.vm-smoke --print-build-logs
```
It boots a VM and passes in a few minutes. **If it fails,** the log shows which `curl` failed; run `nix build … --keep-failed` or add `machine.shell_interact()` temporarily to look around. A failure here on the *unchanged* v0.2.0 code is a real finding; fix the test or the module before refactoring.

### 2.6 A fingerprint for fast parity

Comparing all seven nixlab hosts after every small change is slow. This package dumps the parts of the harness host that matter (units, users, firewall, tmpfiles, rendered configs, secrets wiring) so you can diff before/after in seconds. In `observability-checks.nix`, in the `perSystem` attrset next to `packages.goldens`:

```nix
    packages.fingerprint = let
      c = hosts.stable.config;
      pick = names: set: lib.filterAttrs (n: _: builtins.elem n names) set;
      unitNames = ["prometheus" "loki" "alloy" "grafana" "alertmanager" "ntfy" "prometheus-node-exporter" "loki-permissions" "grafana-permissions" "alloy-permissions" "ntfy-permissions" "prometheus-permissions" "loki-wal-recover" "prometheus-wal-recover" "ntfy-provision" "observability-backup" "maintenance-log-metrics"];
      dump = name: value:
        pkgs.writeText name (builtins.unsafeDiscardStringContext (builtins.toJSON value));
    in
      pkgs.linkFarm "fingerprint" [
        {name = "units.json"; path = dump "units.json" (lib.mapAttrs (_: s: {
          inherit (s) serviceConfig;
          after = s.after or [];
          wants = s.wants or [];
          requires = s.requires or [];
          preStart = s.preStart or "";
          script = s.script or "";
        }) (pick unitNames c.systemd.services));}
        {name = "users.json"; path = dump "users.json" (lib.mapAttrs (_: u: {inherit (u) uid group extraGroups;}) (pick ["loki" "prometheus" "grafana" "ntfy" "alloy"] c.users.users));}
        {name = "firewall.json"; path = dump "firewall.json" {inherit (c.networking.firewall) allowedTCPPorts interfaces;};}
        {name = "tmpfiles.json"; path = dump "tmpfiles.json" c.systemd.tmpfiles.rules;}
        {name = "prometheus.json"; path = dump "prometheus.json" (self.lib.prometheusRendered {config = c; lib = pkgs.lib;});}
        {name = "alertmanager.json"; path = dump "alertmanager.json" c.services.prometheus.alertmanager.configuration;}
        {name = "loki-ruler.json"; path = dump "loki-ruler.json" c.services.loki-nixlab.ruler.groups;}
        {name = "datasources.json"; path = dump "datasources.json" c.services.grafana-nixlab.provisioning.datasources;}
        {name = "loki.json"; path = dump "loki.json" (self.lib.lokiRendered {config = c; lib = pkgs.lib;});}
        {name = "alloy.alloy"; path = dump "alloy.alloy" (self.lib.alloyRendered {config = c; lib = pkgs.lib;});}
        {name = "sops.json"; path = dump "sops.json" (lib.mapAttrs (_: s: {inherit (s) owner restartUnits;}) c.sops.secrets);}
      ];
```
Units that don't exist on the harness host are skipped (`pick` filters by name). `loki.json` and `alloy.alloy` are the rendered configs from §2.3: they are what makes Part 3's "byte-identical" checks real, because store hashes are normalised away in the unit text. Eleven files in total; `ls $BASELINE/obs-fp-0` should show them.

```bash
cd $OBS && git add -A && git commit -qm "test: fingerprint package"   # fp needs a committed tree
fp $BASELINE/obs-fp-0                                                 # the baseline for Parts 3-9
ls $BASELINE/obs-fp-0                                                 # eleven files, none empty
```
**From now on, after every part:** `fp $BASELINE/obs-fp-N && diff -ru $BASELINE/obs-fp-0 $BASELINE/obs-fp-N`. Each part below says what difference, if any, is expected (store hashes are already normalised away).

### 2.7 Run the net

```bash
nix fmt && git add -A
for t in port-defaults loki-runbook-coverage golden-domain-effects loki-config alloy-config; do
  echo "== $t"; nix build ".#checks.x86_64-linux.$t" --no-link --print-build-logs || echo "FAILED: $t"
done
nix flake check --print-build-logs
```
**Check:** no `FAILED:`, `nix flake check` green.

**Commit:**
```bash
git add -A && git commit -m "test: characterization net (ports, loki runbooks, loki/alloy config, domain side effects, vm smoke)"
```

---

## Part 3 — One owner per setting

Four refactors plus one tidy-up, **one commit each**, all behaviour-preserving. After each: `nix flake check`, then `fp $BASELINE/obs-fp-N && diff -ru $BASELINE/obs-fp-0 $BASELINE/obs-fp-N` (commit first; `fp` needs a clean tree). **Expected diff: none**, unless the step says otherwise.

### 3.1 Remove the 0.2 compatibility aliases

Guide 2 §6 marked them `# Remove in 0.3`, and no nixlab host sets those options.

In `stacks/observability.nix`, delete these six lines from `imports`:
```nix
      # Remove in 0.3
      (lib.mkRenamedOptionModule ["services" "loki-nixlab" "alloyPort"] ["services" "alloy-nixlab" "port"])
      (lib.mkRenamedOptionModule ["services" "loki-nixlab" "alloyPackage"] ["services" "alloy-nixlab" "package"])
      (lib.mkRenamedOptionModule ["services" "loki-nixlab" "enableAlloy"] ["services" "alloy-nixlab" "enable"])
      (lib.mkRenamedOptionModule ["services" "loki-nixlab" "maintenance" "enable"] ["services" "maintenance-log-nixlab" "enable"])
      (lib.mkRenamedOptionModule ["services" "loki-nixlab" "maintenance" "logPath"] ["services" "maintenance-log-nixlab" "logPath"])
```
In `flake/ci/observability-checks.nix` delete the `alias = harness.mkTestHost {…};` host (the block containing `services.loki-nixlab.alloyPort = 12999`) and the `alias-alloyport` check.
**Check:** `grep -rn mkRenamedOptionModule modules stacks sops flake` prints nothing; `nix flake check` green; fingerprint diff empty.
**Commit:** `git commit -am "refactor: remove 0.2 option aliases"`

### 3.2 Ports: the option default is the single owner

A port is written three times today (option default, `ports.nix`, stack reads). Keep the first and the last; `port-defaults` (§2.1) makes this test-driven.
```bash
grep -rn "systm--ports" modules stacks sops flake
```
**Do:**
1. In every service module delete `imports = [self.nixosModules.systm--ports-<x>];` (Loki's is the first line of its `let … in {` body; delete the whole `imports` when it becomes empty). The `self` argument stays: `obsLib = self.lib.obsLib;` still uses it.
2. `git rm modules/nixos/observability/ports.nix`
3. Two stale comments in `stacks/observability.nix`: change *"Single source of truth: ports.nix (mkDefault) or a plain assignment in a host file."* to *"Single source of truth: each service's option default, or a plain assignment in a host file."*, and *"Ports are never set here; see ports.nix / host plain assignment."* to *"Ports are never set here."*
4. `git add -A && nix build .#checks.x86_64-linux.port-defaults --no-link`

**If `port-defaults` fails:** each mismatch is an option whose own `default` differed from the `ports.nix` value that used to win. Set that option's `default` to the `want` number. I compared `ports.nix` with every option default in the modules you sent and **all eleven values already agree** (ntfy 2586; Loki 3100/9096; Grafana 3101; Prometheus 9090/9115/9633/9558; Alertmanager 9093/9094; Alloy's 12345 is only an option default), so expect green with no default edits.
**nixlab side:** `cd $NIXLAB && git grep -nE 'systm--ports-(ntfy|loki|grafana|prometheus|alertmanager)'` must print nothing.
**Precedence afterwards:** host plain assignment **>** option default. The `mkDefault` middle tier is gone from this flake.
**Commit:** `git commit -am "refactor(ports): option defaults are the single owner; drop systm--ports-*"`

### 3.3 Hard-coded state paths

The node_exporter textfile directory `/var/lib/node_exporter` is a literal in **four** places: `stacks/observability.nix` (the maintenance-log `textfileDir`), `prometheus/_internals/config.nix` (a tmpfiles rule, and the bridge `nodeExporter.textfileDir = lib.mkIf cfg.maintenance.enable "/var/lib/node_exporter"`), and `prometheus/_internals/exporters/maintenance.nix` (`METRICS_DIR="/var/lib/node_exporter"` in the backup-exporter script). The owner is `host-exporters` (`nodeExporter.textfileDir`); Prometheus' bridge is the one place that chooses the value. Everyone else reads it.

```nix
# stacks/observability.nix
-       textfileDir = lib.mkIf cfg.prometheus.maintenance.enable "/var/lib/node_exporter";
+       textfileDir = lib.mkIf cfg.prometheus.maintenance.enable svc.host-exporters-nixlab.nodeExporter.textfileDir;
# prometheus/_internals/config.nix  (tmpfiles; the bridge line keeps the literal, with a comment saying it is the single source)
-        "d /var/lib/node_exporter 0755 prometheus prometheus -"
+        "d ${config.services.host-exporters-nixlab.nodeExporter.textfileDir} 0755 prometheus prometheus -"
# prometheus/_internals/exporters/maintenance.nix
-      METRICS_DIR="/var/lib/node_exporter"
+      METRICS_DIR="${config.services.host-exporters-nixlab.nodeExporter.textfileDir}"
```
(Both reads are only evaluated when `maintenance.enable` is on, which is exactly when the bridge makes the value non-null.)

The Alertmanager path in the backup list:
```nix
        plainFiles = [
-         "/var/lib/private/alertmanager"
+         # Upstream Alertmanager runs with DynamicUser, so its real state lives under /var/lib/private/<StateDirectory>.
+         "/var/lib/private/${config.systemd.services.alertmanager.serviceConfig.StateDirectory or "alertmanager"}"
          svc.maintenance-log-nixlab.logPath
        ];
```
**Check:** `nix flake check`; fingerprint diff empty (`maintenance-log-metrics`, `observability-backup` and `tmpfiles.json` are all in it).
**Commit:** `git commit -am "refactor(paths): one owner for the textfile dir; derive alertmanager's state path"`

### 3.4 Loki's hard-coded `{job="maintenance-log"}`

The label appears in **two** places that must agree: the stack's Alloy pipeline (`job = "maintenance-log"` in `maintenanceAlloyConfig`) and Loki's `retention_stream` selector. Neither knows about the other, so one owner is needed. The maintenance-log module owns the *log*, so it owns the label.

1. **`maintenance-log/default.nix`**, add to `options.services.maintenance-log-nixlab`:
   ```nix
      lokiJob = lib.mkOption {
        type = lib.types.str;
        default = "maintenance-log";
        description = "Value of the Loki `job` label for this log. Consumers that ship the file must label it with this. The bundled system-overview dashboard (panels 431 and 432) queries the default value.";
      };
   ```
2. **Loki** (`loki/_internals/rendered.nix` after §2.3; otherwise `default.nix`). Add the option:
   ```nix
        retentionStreams = lib.mkOption {
          type = lib.types.listOf (lib.types.submodule {
            options = {
              selector = lib.mkOption {type = lib.types.str; example = ''{job="audit"}'';};
              period = lib.mkOption {type = lib.types.str; example = "17520h";};
              priority = lib.mkOption {type = lib.types.int; default = 1;};
            };
          });
          default = [];
          description = "Per-stream retention overrides (rendered into limits_config.retention_stream).";
        };
   ```
   and in the rendered config replace the literal `retention_stream = [ {selector = ''{job="maintenance-log"}''; priority = 1; period = "17520h";} ];` inside `limits_config` by closing `limits_config` and appending:
   ```nix
                limits_config = { …everything except retention_stream… }
                  // lib.optionalAttrs (cfg.retentionStreams != []) {
                    retention_stream = map (s: {inherit (s) selector priority period;}) cfg.retentionStreams;
                  };
   ```
3. **Stack:** in the `services.loki-nixlab = {…}` block add
   ```nix
        retentionStreams = [
          {
            selector = ''{job="${svc.maintenance-log-nixlab.lokiJob}"}'';
            priority = 1;
            period = "17520h";
          }
        ];
   ```
   and in `maintenanceAlloyConfig` change `job  = "maintenance-log",` to `job  = "${svc.maintenance-log-nixlab.lokiJob}",`.

A standalone Loki (without the stack) no longer gets the 2-year maintenance override by default. Say so in the CHANGELOG. Also note: two panels of `system-overview-v5.json` (ids 431 and 432) query `{job="maintenance-log"…}` literally, so keep `lokiJob` at its default if you use the bundled dashboard (§8.3 shows how to template it if you ever need to).
**Check:** `nix build .#checks.x86_64-linux.loki-config`; the fingerprint's `loki.json` (the rendered Loki config) and `alloy.alloy` are **byte-identical** to `obs-fp-0`.
**Commit:** `git commit -am "refactor(loki): stream retention is an option; maintenance label owned by maintenance-log"`

### 3.5 Stale comments in the stack

In `stacks/observability.nix`: *"The helper follows Loki's maintenance settings so the file Alloy tails…"* → *"The helper follows loki.maintenance.enable; Alloy tails its logPath."* and the "Override contract" bullet *"Ports are never set here; see ports.nix / host plain assignment."* (if still present).
**Commit:** `git commit -am "docs(stack): fix stale comments"`

---

## Part 4 — Stable module keys

### 4.1 Why (30 seconds)

NixOS dedupes "the same module imported twice" by a `key`. Modules from flake outputs have none, so each import path gets its own identity and the options are declared twice. A consumer who imports `loki` **and** the whole stack, which is a perfectly natural thing to do, gets `option … is already declared`. Guide 2 §7.2b *forbade* that. A key makes it harmless.

### 4.2 Test first (red)

Create `flake/ci/contract-checks.nix` (permanent contract tests; this folder's files get names rewritten in Part 5, which is what you want):

```nix
{self, inputs, lib, ...}: {
  perSystem = {system, ...}: let
    harness = import ./_harness {inherit inputs self;};
  in {
    checks = lib.optionalAttrs (system == "x86_64-linux") {
      # Importing individual modules on top of the stack must be harmless.
      double-import =
        (harness.mkTestHost {
          modules = [
            harness.minimalStack
            self.nixosModules.servc--loki-nixlab
            self.nixosModules.servc--grafana-nixlab
            self.nixosModules.servc--prometheus-nixlab
          ];
        }).config.system.build.toplevel;
    };
  };
}
```
```bash
git add -A
nix build .#checks.x86_64-linux.double-import --no-link 2>&1 | grep -m2 "error\|already declared"
```
**Check (success = failure):** `already declared in …`.

### 4.3 Add the helper

In `flake/lib/obs-lib.nix`, inside the `flake.lib.obsLib = { … }` attrset add:

```nix
    # Give a module a stable identity so importing it twice is harmless.
    keyed = key: module: {
      inherit key;
      imports = [module];
    };
```
`nix eval .#lib.obsLib --apply builtins.attrNames` now lists seven names.

### 4.4 Wrap every public module (12 files, two lines each)

Pattern, shown with Loki. **Before:**
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
    …
  };
}
```
**After** (only the first line and the closing `;` of the module change; let `nix fmt` re-indent):
```nix
{self, ...}: {
  flake.nixosModules.servc--loki-nixlab = self.lib.obsLib.keyed "observability:loki" ({
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.services.loki-nixlab;
    obsLib = self.lib.obsLib;
  in {
    …
  });
}
```

Keys to use (these are the **new** names, so they won't change in Part 5):

| File | Key |
|---|---|
| `…/prometheus/default.nix` | `observability:prometheus` |
| `…/alertmanager/default.nix` | `observability:alertmanager` |
| `…/ntfy/default.nix` | `observability:ntfy` |
| `…/loki/default.nix` | `observability:loki` |
| `…/alloy/default.nix` | `observability:alloy` |
| `…/grafana/default.nix` | `observability:grafana` |
| `…/host-exporters/default.nix` | `observability:host-exporters` |
| `…/maintenance-log/default.nix` | `observability:maintenance-log` |
| `…/observability-backup/default.nix` | `observability:backup` |
| `stacks/observability.nix` | `observability:stack` |
| `sops/alertmanager.nix` | `observability:sops-alertmanager` |
| `sops/grafana.nix` | `observability:sops-grafana` |

**Outer arguments.** `maintenance-log/default.nix` and `observability-backup/default.nix` start with `{...}:`, and Guide 2 §7.2b turned both `sops/*.nix` files back into `{...}:`. Each needs `self`, so change those four first lines to `{self, ...}:`. Loki, Alloy, Grafana, ntfy, Alertmanager, host-exporters, Prometheus and the stack already take `self`.

**Check:**
```bash
nix fmt && git add -A
nix build .#checks.x86_64-linux.double-import --no-link --show-trace 2>&1 | tail -5     # now succeeds
nix flake check --print-build-logs
```
**If it still says "already declared":** the key isn't on the module that declares the option. Find the file named in the error and confirm it was wrapped (a module that is its own `{…}: {…}` function but wasn't wrapped is the usual miss). If the error names *two different* files, you have two real modules declaring the same option, which is a different bug.
**Fingerprint diff:** none. **Commit:** `git commit -am "refactor(modules): stable keys; importing a module twice is harmless"`

---

## Part 5 — Rename and flatten

### 5.1 The rename map (a decision: record it in ADR-010 first)

ADR-003 settles three things and leaves two open. **Settled:** names are the API; renaming happens in Guide 3 with `mkRenamedOptionModule` aliases kept for one minor release; the category prefixes `servc--`, `systm--`, `stack--`, `nsops--` **stay** (decision 4). **Open (decision 5):** generic (`servc--loki`) or product-scoped (`servc--observability-loki`) names, to be decided before 1.0 in a *superseding ADR*. So the rename needs an ADR, and the numbers 010–012 are reserved for Guide 3 in your ADR index.

My recommendation is **product-scoped**: you already merge another flake's `nixosModules` into yours (`flake/observability.nix` does `flake.nixosModules = inputs.observability.nixosModules`), so a generic `servc--loki` could collide with a module of your own, or of anyone else's. Option names are flat (`services.observability-loki`, not `services.observability.loki`) because the stack's aggregator already declares `services.nixlab-observability.loki.*` and `.prometheus.*`; a nested service namespace would collide with those.

Write `docs/architecture/decisions/ADR-010-final-names.md`:
```markdown
# ADR-010: Final module and option names

- **Status:** Accepted (<date>)
- **Supersedes:** ADR-003 decisions 4 and 5 (decisions 1–3 stand). Update ADR-003's status line to "Accepted; decisions 4–5 superseded by ADR-010".
- **Related:** ADR-003, ADR-005

## Context
ADR-003 deferred the final names. The `-nixlab` suffix is misleading for outside consumers, and consumers may merge several flakes' `nixosModules`, so generic names risk collisions.

## Decision
1. Category prefixes stay: `servc--` (single service), `systm--` (supporting capability), `stack--` (aggregator), `nsops--` (optional sops wiring).
2. Names are product-scoped: `<prefix>--observability-<component>` (the aggregator keeps `stack--observability`). Options are `services.observability-<component>`; the aggregator is `services.observability`.
3. The old names remain as generated, deprecated aliases for one minor release (0.3.x) and are removed in 0.4.0.
4. Systemd unit names, users, groups, directories and generated file names do not change.

## Alternatives considered
- Generic names (`servc--loki`): collision risk. Keep the `-nixlab` suffix: misleading. Nested options (`services.observability.loki`): collides with the aggregator's own options.

## Consequences / migration
Consumers set the new option names; old ones warn until 0.4.0. nixlab migrates in two stages (Guide 3, Part 10).
```
Add a row for 010 (and 011, §11.1) to `docs/architecture/decisions/README.md`.

`docs/development/migration/rename-map.txt` (two whitespace-separated columns: old, new). `stack--observability` **does not change**, which also means nixlab's `stack--observability-nixlab` adapter is never touched by the script:

```
servc--prometheus-nixlab             servc--observability-prometheus
servc--alertmanager-nixlab           servc--observability-alertmanager
servc--ntfy-nixlab                   servc--observability-ntfy
servc--loki-nixlab                   servc--observability-loki
servc--alloy-nixlab                  servc--observability-alloy
servc--grafana-nixlab                servc--observability-grafana
systm--host-exporters-nixlab         systm--observability-host-exporters
systm--maintenance-log-nixlab        systm--observability-maintenance-log
systm--observability-backup-nixlab   systm--observability-backup
nsops--alertmanager                  nsops--observability-alertmanager
nsops--grafana                       nsops--observability-grafana
services.nixlab-observability        services.observability
services.prometheus-nixlab           services.observability-prometheus
services.alertmanager-nixlab         services.observability-alertmanager
services.ntfy-nixlab                 services.observability-ntfy
services.loki-nixlab                 services.observability-loki
services.alloy-nixlab                services.observability-alloy
services.grafana-nixlab              services.observability-grafana
services.host-exporters-nixlab       services.observability-host-exporters
services.maintenance-log-nixlab      services.observability-maintenance-log
services.observability-backup-nixlab services.observability-backup
```
**What does *not* change (E2):** `-nixlab` in unit names, users, groups, directories, file names. Only these tokens change; §5.5 makes you review anything left over.

### 5.2 The rename script

`docs/development/migration/rename-tokens.sh`:

```bash
#!/usr/bin/env bash
# usage: rename-tokens.sh <map> <path>...   (run at the root of a git repo; rewrites TRACKED files only)
set -euo pipefail
map=$1; shift
# longest "old" first, so a long name is never clobbered by a shorter prefix of itself
awk 'NF==2 {print length($1), $1, $2}' "$map" | sort -rn | cut -d' ' -f2- |
while read -r old new; do
  git grep -lF -e "$old" -- "$@" 2>/dev/null | while read -r f; do
    OLD="$old" NEW="$new" perl -pi -e 'BEGIN{$o=quotemeta($ENV{OLD}); $n=$ENV{NEW}} s/(?<![\w-])$o(?![\w-])/$n/g' "$f"
  done
done
```
The lookarounds mean `stack--observability` is replaced but `stack--observability-nixlab` (nixlab's adapter!) is not, and `services.loki-nixlab` never matches inside a longer name.

### 5.3 Test first (red)

Create `compat/checks.nix` (temporary: it is deleted in 0.4.0 and is outside the script's scope on purpose, because it mentions **old** names):

```nix
{self, inputs, lib, ...}: {
  perSystem = {pkgs, system, ...}: let
    harness = import ../flake/ci/_harness {inherit inputs self;};
    nm = self.nixosModules;
    newNames = ["default" "servc--observability-prometheus" "servc--observability-alertmanager" "servc--observability-ntfy" "servc--observability-loki" "servc--observability-alloy" "servc--observability-grafana" "systm--observability-host-exporters" "systm--observability-maintenance-log" "systm--observability-backup" "nsops--observability-alertmanager" "nsops--observability-grafana"];
    oldNames = ["servc--prometheus-nixlab" "servc--alertmanager-nixlab" "servc--ntfy-nixlab" "servc--loki-nixlab" "servc--alloy-nixlab" "servc--grafana-nixlab" "systm--host-exporters-nixlab" "systm--maintenance-log-nixlab" "systm--observability-backup-nixlab" "nsops--alertmanager" "nsops--grafana"];
    missing = lib.filter (n: !(nm ? ${n})) (newNames ++ oldNames);
    aliases = builtins.fromJSON (builtins.readFile ./option-aliases.json);
    deadTargets = lib.filter (a: !(lib.hasAttrByPath a.new (hosts.stable.options))) aliases;
    hosts.stable = harness.mkTestHost {modules = [harness.fullStack harness.withSops];};
  in {
    checks = lib.optionalAttrs (system == "x86_64-linux") {
      compat-names = pkgs.runCommand "compat-names" {} ''
        ${lib.optionalString (missing != []) ''echo "missing module names: ${toString missing}"; exit 1''}
        touch $out
      '';
      compat-alias-targets = pkgs.runCommand "compat-alias-targets" {} ''
        ${lib.optionalString (deadTargets != []) ''echo "alias targets that do not exist: ${builtins.toJSON deadTargets}"; exit 1''}
        touch $out
      '';
      # An old-style setting at a LOWER priority must lose to a new-style plain setting.
      # (If the alias dropped the priority, both would be equal and the list would concatenate.)
      alias-priority = let
        h = harness.mkTestHost {
          modules = [
            harness.minimalStack
            {
              services.nixlab-observability.access.interfaces = lib.mkDefault ["eth0"];
              services.observability.access.interfaces = ["eth1"];
            }
          ];
        };
      in
        pkgs.runCommand "alias-priority" {} ''
          test '${builtins.toJSON h.config.services.observability.access.interfaces}' = '["eth1"]'
          touch $out
        '';
      # A consumer written against 0.2: old module names AND old option names.
      old-style-consumer =
        (harness.mkTestHost {
          modules = [
            nm.servc--loki-nixlab
            nm.systm--maintenance-log-nixlab
            {services.maintenance-log-nixlab.enable = true;}
          ];
        }).config.system.build.toplevel;
    };
  };
}
```
and add `(inputs.import-tree ./compat)` to `imports` in `flake.nix`.

```bash
git add -A
nix build .#checks.x86_64-linux.compat-names --no-link 2>&1 | grep -m1 -i "error\|missing"
```
**Check (success = failure):** red. Commit the red state: `git commit -m "test: compatibility contract (intentionally failing)"`.

### 5.4 Dump the old option paths (before renaming!)

Temporarily add to `observability-checks.nix`'s `perSystem` (**do not commit this edit**):

```nix
    packages.option-paths = let
      prefixes = ["nixlab-observability" "prometheus-nixlab" "alertmanager-nixlab" "ntfy-nixlab" "loki-nixlab" "alloy-nixlab" "grafana-nixlab" "host-exporters-nixlab" "maintenance-log-nixlab" "observability-backup-nixlab"];
      leaves = lib.concatMap (p: map (o: o.loc) (lib.collect lib.isOption hosts.stable.options.services.${p})) prefixes;
    in toJson "option-paths.json" leaves;
```
```bash
git add -A && nix build .#packages.x86_64-linux.option-paths -o /tmp/old-paths
cp -L /tmp/old-paths compat/old-option-paths.json
git restore --staged flake/ci/observability-checks.nix && git restore flake/ci/observability-checks.nix   # drop the temporary package
jq length compat/old-option-paths.json; jq -c '.[0:3][]' compat/old-option-paths.json
```
**Check:** a few hundred paths (the exact count is your option count); each looks like `["services","loki-nixlab","port"]`. Every one of these old option names is a public option a consumer may have set.
**Commit:** `git add -A && git commit -m "chore(compat): record every pre-0.3 option path"`

### 5.5 Apply the rename

```bash
cd $OBS
mkdir -p docs/development/migration
# create rename-map.txt and rename-tokens.sh from 5.1 / 5.2, then:
git add -A && git commit -qm "chore(migration): rename map and script"
bash docs/development/migration/rename-tokens.sh docs/development/migration/rename-map.txt modules stacks sops flake examples
nix fmt && git add -A
git diff --stat | tail -3
legacy | head -40
```
Add one tiny file so `default` exists, `stacks/default.nix`:
```nix
{self, ...}: {flake.nixosModules.default = self.nixosModules.stack--observability;}
```
**Review every line `legacy` still prints.** Two kinds are legitimate and stay: a state path / unit name / file name that happens to contain `-nixlab`, and a comment about history. Anything else is a nested-attribute spelling the script can't see (e.g. `services = { loki-nixlab = {…}; }`); rename it by hand. **Never** rename a unit, user or directory (E2).

**Check:** `legacy | wc -l` is 0, or every remaining line is explained in your commit message.
**Commit:** `git commit -am "refactor: neutral module and option names (aliases follow in 5.8)"`

### 5.6 Flatten the layout (a pure move: no edits in this commit)

```bash
cd $OBS
for s in prometheus alertmanager ntfy loki alloy grafana host-exporters maintenance-log; do
  git mv modules/nixos/observability/$s modules/nixos/$s
done
git mv modules/nixos/observability/observability-backup modules/nixos/backup
ls modules/nixos                       # eight service dirs + backup, no observability/
git commit -m "refactor(layout): flatten modules/nixos/<service>"
```
Then fix what moved, in a *separate* commit:
```bash
grep -rn '\.\./\|modules/nixos/observability' modules stacks sops flake docs/architecture examples
```
Most imports are same-directory (`./_internals/…`, `./dashboards`) and need nothing. Fix any hit that crosses a service directory. One known string: the Grafana `extraDashboards` assertion message says `modules/nixos/observability/grafana/dashboards/`; change it to `modules/nixos/grafana/dashboards/`.
**Check:** `nix flake check` and `nix build .#checks.x86_64-linux.toplevel-stable --no-link` green; `fp $BASELINE/obs-fp-5 && diff -ru $BASELINE/obs-fp-0 $BASELINE/obs-fp-5` shows **only** lines where a path changed from `modules/nixos/observability/<svc>` to `modules/nixos/<svc>` (the Grafana dashboards directory). Nothing else.
**Commit:** `git commit -am "refactor(layout): fix relative references after flatten"`

### 5.7 Generate the compatibility layer

**(a) Old module names → new modules** (generated, deprecated, deleted in 0.4.0):
```bash
mkdir -p compat
{
  echo '# Deprecated pre-0.3 module names. Removed in 0.4.0 — migrate to the names in docs/architecture/public-api.md.'
  echo '{self, ...}: {'
  echo '  flake.nixosModules = {'
  awk 'NF==2 && $1 !~ /^services\./ { printf "    %s = {imports = [self.nixosModules.%s self.nixosModules.compat-options];};\n", $1, $2 }' $MAP
  echo '  };'
  echo '}'
} > compat/module-names.nix
```
Importing the old name also pulls in the option aliases; Part 4's keys make the double import a no-op.

**(b) Old option names → new options** (per leaf, E3). Build the alias list from the dump in 5.4:
```bash
jq --argjson m "$(awk -F' +' 'BEGIN{printf "{"} $1 ~ /^services\./ {o=$1; n=$2; sub(/^services\./,"",o); sub(/^services\./,"",n); printf "%s\"%s\":\"%s\"", sep, o, n; sep=","} END{printf "}"}' $MAP)" \
  '[ .[] | {old: ., new: ([.[0], $m[.[1]]] + .[2:])} ]' compat/old-option-paths.json > compat/option-aliases.json
jq -e 'all(.[]; .new | all(. != null))' compat/option-aliases.json     # prints true
```
`compat/options.nix`:
```nix
{self, ...}: {
  flake.nixosModules.compat-options = self.lib.obsLib.keyed "observability:compat-options" ({lib, ...}: {
    # Deprecated pre-0.3 option names; each use prints a warning. Removed in 0.4.0.
    imports = map (a: lib.mkRenamedOptionModule a.old a.new) (builtins.fromJSON (builtins.readFile ./option-aliases.json));
  });
}
```
Add `self.nixosModules.compat-options` to the stack's `imports`.

### 5.8 Check

```bash
nix fmt && git add -A
for t in compat-names compat-alias-targets alias-priority old-style-consumer double-import toplevel-stable toplevel-external toplevel-minimal; do
  echo "== $t"; nix build ".#checks.x86_64-linux.$t" --no-link --print-build-logs || echo "FAILED: $t"
done
nix build ./examples/minimal#nixosConfigurations.demo.config.system.build.toplevel --override-input observability "path:$PWD" --no-link
nix flake check --print-build-logs
```
**If `compat-alias-targets` lists targets:** an option was renamed by the script but also *moved* in §3 (e.g. ports/paths) or is declared only on some module sets. For each, either fix the map or add the option to the module. **If `alias-priority` fails with `["eth0","eth1"]`:** your nixpkgs' `mkRenamedOptionModule` isn't preserving priority; use `lib.mkRenamedOptionModuleWith {from; to; sinceRelease = 2505;}` for the aliases instead.
**Commit:** `git add -A && git commit -m "feat(compat): generated aliases for pre-0.3 module and option names"`

---

## Part 6 — Hermetic scripts

`bin/mon-*.sh` assume `curl`, `jq`, `ss`, `awk`… are on the host `PATH`. Package them with their tools; `systemctl`, `systemd-analyze`, `nix` and `id` stay the host's (`writeShellApplication` appends the host `PATH` after `runtimeInputs`).

### 6.1 What they actually use (from the scripts you sent)

| Script | External tools | Notes |
|---|---|---|
| `mon-check.sh` | `curl jq systemctl bash seq date grep` | `bash -c` is used inside `check`, so `bash` must be on `PATH`; `date -d` is GNU date |
| `mon-snapshot.sh` | `systemctl sed cp curl jq ss awk sort systemd-analyze` | `ss` is `iproute2`; hard-codes `localhost:9093` |
| `mon-unitdiff.sh` | `sed diff ls nix` | needs host `nix` for `store diff-closures` |

### 6.2 Replace `flake/ci/apps.nix`

```nix
{...}: {
  perSystem = {pkgs, lib, ...}: let
    common = with pkgs; [bash coreutils gnugrep gnused gawk curl jq iproute2 findutils];
    mk = {name, file, extra ? [], exclude ? []}:
      pkgs.writeShellApplication {
        inherit name;
        runtimeInputs = common ++ extra;
        excludeShellChecks = exclude;
        text = builtins.readFile file;
      };
    scripts = {
      mon-check = mk {name = "mon-check"; file = ../../bin/mon-check.sh;};
      mon-snapshot = mk {name = "mon-snapshot"; file = ../../bin/mon-snapshot.sh;};
      mon-unitdiff = mk {name = "mon-unitdiff"; file = ../../bin/mon-unitdiff.sh; extra = [pkgs.diffutils];};
    };
  in {
    packages = scripts;
    apps = lib.mapAttrs (n: p: {
      type = "app";
      program = lib.getExe p;
      meta.description = "Observability ${n}";
    }) scripts;
  };
}
```
`writeShellApplication` **runs shellcheck at build time** (every severity, including "info") and adds `set -o errexit -o nounset -o pipefail`.

### 6.3 Fix what shellcheck finds

```bash
git add -A && nix build .#mon-check .#mon-snapshot .#mon-unitdiff --no-link --print-build-logs 2>&1 | grep -E '^In |SC[0-9]+' | head -30
```
Expected, from reading the scripts:

| Script | Likely finding | Fix |
|---|---|---|
| `mon-check.sh` | SC2086 on `for u in $UNITS` and on `${MON_NTFY_AUTH:+-u "$MON_NTFY_AUTH"}` | `read -ra units <<<"$UNITS"; for u in "${units[@]}"` ; build an `auth=()` array: `auth=(); [ -n "${MON_NTFY_AUTH:-}" ] && auth=(-u "$MON_NTFY_AUTH")` then `"${auth[@]}"` |
| `mon-check.sh` | SC2015 on every `[ … ] && ok … \|\| bad …` | rewrite as `if [ … ]; then ok …; else bad …; fi`, or pass `exclude = ["SC2015"]` (the pattern is safe here because `ok` cannot fail) |
| `mon-unitdiff.sh` | SC2045 (`for f in $(… ls …)`) and SC2086 | use `find … -printf '%f\n'` piped into `while read -r f`, or `exclude = ["SC2045" "SC2086"]` with a comment |
| `mon-snapshot.sh` | probably clean | |

`mon-check.sh` was written with `set -u` but **without** `-e`, on purpose (it keeps going after a failed check). Reading it, every command that may fail is already inside an `if`, an `||`, or an `&&` list, so `errexit` is safe, but run it on a host with one service stopped to prove it still prints every FAIL line and exits 1.
Fix the **script files** (`bin/*.sh` remain the source of truth and stay runnable standalone, with their shebangs).
**Check:**
```bash
nix run .#mon-check -- --help 2>&1 | head -3       # the script has no --help; any normal output without "command not found" is the proof
env -i PATH=/run/current-system/sw/bin "$(nix build .#mon-check --no-link --print-out-paths)/bin/mon-check" | head   # works with a bare PATH
```
Run the real thing on the canary in Part 10.
**Commit:** `git commit -am "feat(scripts): hermetic mon-check, mon-snapshot, mon-unitdiff (packages + apps)"`

---

## Part 7 — Docs: split, scrub, generate

### 7.1 Target layout

```
docs/
├── README.md                    # index: what to read for which question
├── architecture/                # public-api.md, overview.md, decisions/ (ADRs)
├── operations/                  # install-and-configure.md, monitoring-the-monitor.md, backup-restore.md, secret-rotation.md, upgrading.md
├── reference/options.md         # GENERATED (7.4): never hand-edit
├── runbooks/                    # one page per alert (unchanged)
├── development/                 # extending.md, testing.md, migration/ (the three guides, parity reports)
└── llm-context.md               # the old §0 "context card"
```

### 7.2 Split `docs/wiki/observability.md`, and fix it while you do

The file is a good document written *before* Guide 2, so large parts describe code that no longer exists. Split first:
```bash
cd $OBS
mkdir -p /tmp/split && rm -f /tmp/split/*
csplit -z -f /tmp/split/sec- -b '%02d.md' docs/wiki/observability.md '/^## /' '{*}'
head -qn1 /tmp/split/sec-*.md
```
Assignment: **§0** → `llm-context.md`; **§1–2** → `architecture/overview.md`; **§4–8, 10–12** → `architecture/` (components, alerting, data flows, runtime layout, resilience); **§9** → `operations/secrets.md`; **§13** → `development/testing.md`; **§14, 17** → `operations/`; **§15** → `development/extending.md`; **§3** → delete.

Then fix these stale statements (each verified against the code you sent):

| Where in the wiki | It says | Code now |
|---|---|---|
| Scope paragraph, §4 file map | `modules/ports.nix`, `flake/nixos-lib.nix`, `tools/observability-cleanup.py` | ports are option defaults (3.2); helpers are `flake/lib/obs-lib.nix`; the cleanup script is not in the repo |
| §0, "Hosts" and "Ports" paragraphs | seven named hosts, IPs `10.0.0.200–204`, `hosts--profl--base` defaults, "defaults come from `modules/ports.nix`" | delete; keep only product defaults (stack defaults: scrape 30 s, Prometheus 15 d, Loki 744 h) |
| §3 | all of it (nixlab hosts and profile) | delete (7.3) |
| §5 header and options table | imports `nsops--*`, takes `hostMeta`, reads `self.lib.hostsMeta`/`serviceRegistry`; `publicHost` default `hostMeta.address`; `probes.hosts`, `probes.tcpFromRegistry`; `access.interfaces` "never Wi-Fi" | the stack imports the six service modules plus maintenance-log and backup; `publicHost`/`probes.gateway` default `null`; options are `probes.{gateway,icmpTargets,tcpTargets}`; policy is ADR-008/011 |
| §5.3 wiring table | "Alloy enabled from Loki's `enableAlloy`…", "`maintenance-log` follows Loki's `maintenance.*`", "ntfy auth … `ALERTMANAGER_ENV` secret path; changed secret restarts `ntfy-provision`" | Alloy `enable = mkDefault true`; `maintenance-log-nixlab.enable` follows `loki.maintenance.enable`; ntfy auth uses `ntfyAuth.environmentFile`; the restart wiring lives in `nsops--…alertmanager` |
| §6.1 | `runbookBase` hard-coded to `…/observability/blob/main/docs/runbooks` | option `prometheus-nixlab.runbookBaseUrl` (Guide 2 Part 8) |
| §6.5 | "Options read by the stack, not by Loki: `enableAlloy`, `alloyPackage`, `alloyPort`, `maintenance.*`" | removed from Loki in 0.2; a `retentionStreams` option exists after 3.4 |
| §6.7 | default dashboards `maintenance` → `maintenance-checklist.json` and `system-overview-v5`; a `maintenance-checklist.json` row in the dashboard table | the module default provisions only `system-overview-v5` (the `maintenance` entry is commented out and that JSON file is not in the repo) |
| §9 | stack imports the sops modules | optional (ADR-009) |
| §11 | `nixlabLib` injected via `specialArgs` | `obsLib`, from `self.lib.obsLib` (ADR-006) |
| §13 | checks run on `nixnas1` and `nixsun` | harness hosts `stable`/`unstable`/`external`/`minimal`, plus the Part 2–5 checks |
| §14.2 and "Companion docs" | `docs/secrets-rotation.md`, `docs/design-review.md`, `bin/rotate-secret.sh` | **none of these exist** in your file list: write the rotation doc (11.5) or remove the references |
| §16 | an empty heading | write it (open findings from this guide) or delete it |
| Appendix | host example with `services.nixlab-observability…` | new names after Part 5 |

Also scrub the script headers: `mon-check.sh` says "nixlab observability stack".
```bash
git rm docs/wiki/observability.md
```

### 7.3 Scrub nixlab-specific content

```bash
git grep -nE '10\.0\.0\.|Temhr/nixlab|nixnas|nixace|nixsun|nixtop|nixvat|nixzen|zb17|zb15|m720q|hosts--profl' -- . ':!docs/development/migration' ':!CHANGELOG.md'
```
Replace each hit with a neutral example (`192.0.2.x`, `host-a`) or delete it. (Examples already in the code that hit: the `externalUrl` option examples in Alertmanager, Grafana, ntfy and Prometheus use `10.0.0.251` and `10.0.0.10`; the first is your `nixnas1`.) The migration guides legitimately mention your hosts; that folder stays out of the scrub (if you ever go public, read it first). Runbooks that mention ZFS/NVMe/SMART as hardware examples are fine.
**Check:** the `grep` prints nothing.

### 7.4 Generated options reference

`flake/ci/docs.nix`:
```nix
{self, inputs, lib, ...}: {
  perSystem = {pkgs, system, ...}: let
    harness = import ./_harness {inherit inputs self;};
    host = harness.mkTestHost {modules = [harness.fullStack harness.withSops];};
    ours = opt: lib.hasPrefix "services.observability" (lib.showOption opt.loc);
    doc = pkgs.nixosOptionsDoc {
      options = lib.filterAttrs (n: _: n == "services") host.options;
      warningsAreErrors = false;   # flip to true in Part 13
      transformOptions = opt:
        opt // {
          visible = opt.visible && ours opt;
          declarations = map (d: lib.removePrefix "${toString self}/" (toString d)) opt.declarations;
        };
    };
  in {
    packages.options-doc = doc.optionsCommonMark;
    checks = lib.optionalAttrs (system == "x86_64-linux") {
      options-doc-fresh = pkgs.runCommand "options-doc-fresh" {nativeBuildInputs = [pkgs.diffutils];} ''
        diff -u ${self}/docs/reference/options.md ${doc.optionsCommonMark} \
          || { echo "stale: nix build .#options-doc -o /tmp/o && cp -L /tmp/o docs/reference/options.md"; exit 1; }
        touch $out
      '';
    };
  };
}
```
```bash
mkdir -p docs/reference && git add -A
nix build .#options-doc -o /tmp/o && cp -L /tmp/o docs/reference/options.md && git add -A
grep -c '^## ' docs/reference/options.md
grep -m3 'Declared by' -A2 docs/reference/options.md      # repo-relative paths, not /nix/store
```
If "Declared by" shows store paths, adjust the `removePrefix` so it matches `toString self`. Options without a description now show up as gaps; closing them is a Part 13 criterion. (Compat aliases declared at old names are excluded by the `ours` prefix test and are `visible = false` anyway.)

### 7.5 Link check

In the `checks` block of `flake/ci/observability-checks.nix`:
```nix
        docs-links = pkgs.runCommand "docs-links" {nativeBuildInputs = [pkgs.lychee];} ''
          cd ${self}
          lychee --offline --no-progress README.md docs
          touch $out
        '';
```
(`lychee --help` should list `--offline`; if not, replace this with a `grep`-based relative-link test.) The split in 7.2 is where broken links come from.

### 7.6 Update the public contract

`docs/architecture/public-api.md` (retitle **v0.3**). Fix what is wrong today:
- the 0.2 breaking-changes table has a typo: the row `oki-nixlab.{enableAlloy,…}` should read `loki-nixlab.{enableAlloy,…}`;
- "Host prerequisites" says *state root (`dataDir`, default /data/observability)*; the stack's default is `/data`, with `/data/<service>` below it;
- "Internal" lists `systm--ports-*`, which no longer exist after 3.2.

Then: (1) replace every old name with the new one and add a **Deprecated names** table generated from `$MAP` (columns *old / new / removed in*, all `0.4.0`); (2) add sections **Module keys** (any public module may be imported alone, together, or via the stack; each applies once), **Ports** (precedence: host plain assignment > option default; no ports modules), and **Side effects** (setting `domain` on a service enables nginx and opens firewall ports; the exact effect is pinned by `flake/ci/_golden/domain-effects.json`; paste its contents); (3) add `obsLib.keyed` to Internal.

`CHANGELOG.md`:
```markdown
## 0.3.0
### Breaking
- Removed the 0.2 aliases `loki-nixlab.{enableAlloy,alloyPort,alloyPackage}` and `loki-nixlab.maintenance.*`.
- Removed `systm--ports-*` modules; ports are option defaults (values unchanged).
- A standalone Loki (without the stack) no longer gets the 2-year `{job="maintenance-log"}` retention by default; the stack sets it via `retentionStreams`.
- Repository layout flattened (`modules/nixos/<service>/`); not public API.
### Deprecated (removed in 0.4.0)
- All `-nixlab` option names and module names (see ADR-010 and docs/architecture/public-api.md).
### Added
- Product-scoped names (ADR-010), `default` module, stable module keys, hermetic `mon-*` packages.
- Checks: `port-defaults`, `loki-config`, `alloy-config`, `loki-runbook-coverage`, `golden-domain-effects`, `double-import`, `options-doc-fresh`, `docs-links`, compat checks; `vm-smoke` package.
- Options: `services.observability-loki.retentionStreams`, `services.observability-maintenance-log.lokiJob`, `services.observability.integrations.nvidia.enable`.
```
**Check / Commit:**
```bash
nix fmt && git add -A && nix flake check --print-build-logs
git commit -am "docs: split, scrub, generated options reference, public API v0.3"
```

---

## Part 8 — Gate nixlab-specific content

### 8.1 The NVIDIA Xid rule

In `stacks/observability.nix`:

1. In `integrations = {…}` add:
   ```nix
        nvidia.enable = lib.mkEnableOption "the NVIDIA Xid log alert (needs the NVIDIA kernel driver)";
   ```
2. In the `journal` rule group, split the `rules` list around `NvidiaXid` **so the order does not change** (the order is visible in `loki-ruler.json`):
   ```nix
        rules =
          [
            { alert = "JournalOOMKill"; … }
            { alert = "KernelFilesystemError"; … }
          ]
          ++ lib.optional cfg.integrations.nvidia.enable {
            alert = "NvidiaXid";
            …unchanged…
          }
          ++ [
            { alert = "SSHAuthFailureBurst"; … }
          ];
   ```
The default is off. **Behaviour-preserving for nixlab means the adapter turns it on everywhere (E6):** Stage A adds `services.nixlab-observability.integrations.nvidia.enable = lib.mkDefault true;` to the adapter (old name; Stage B renames it).

Test, in the `checks` block:
```nix
        nvidia-gated = let
          on = harness.mkTestHost {modules = [harness.minimalStack {services.nixlab-observability.integrations.nvidia.enable = true;}];};
          rules = h: builtins.toJSON h.config.services.loki-nixlab.ruler.groups;
        in
          assert !(lib.hasInfix "NvidiaXid" (rules hosts.minimal));
          assert lib.hasInfix "NvidiaXid" (rules on);
            pkgs.runCommand "nvidia-gated" {} "touch $out";
```
(Part 5's script rewrites these names.)

### 8.2 ZFS alerts that need metrics only nixlab produces

Six alerts in `zfs_health` query `zfs_vdev_errors`, `zfs_pool_error_count`, `zfs_last_scrub_end_timestamp_seconds`, `zfs_last_scrub_errors`, `zfs_expected_device_present` and `zfs_device_last_auto_online_timestamp_seconds`: `ZpoolDeviceErrors`, `ZpoolDataErrors`, `ZpoolScrubOverdue`, `ZpoolScrubErrors`, `ZpoolMemberMissing`, `ZpoolMemberReonlined`. node_exporter does not produce these; your NAS hosts do, through scripts and textfile metrics that live in **nixlab** (the alert text even names `zfs-member-reconcile`; I haven't seen that code, Appendix C). The two generic ZFS alerts (`ZpoolNotOnline`, `ZpoolLowFree`, from node_exporter's own ZFS collector) stay ungated. The opt-in `zfs-monitoring` dashboard uses the same custom metrics.

1. `prometheus/_internals/options.nix`, inside `alerts.features`:
   ```nix
        zfsMembers = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Load the ZFS member/scrub alerts. Requires the textfile metrics zfs_vdev_errors, zfs_pool_error_count, zfs_last_scrub_end_timestamp_seconds, zfs_last_scrub_errors, zfs_expected_device_present and zfs_device_last_auto_online_timestamp_seconds (see docs/operations/zfs-metrics.md).";
        };
   ```
2. `maintenance-alerts.nix`: add `requires = "zfsMembers";` to those six rules (same pattern as `requires = "backup";`).
3. `flake/ci/observability-checks.nix`: add `zfsMembers = true;` to `allFeatures`, so `prom-rules-all-features`, `runbook-coverage` and the rule tests still see them.
4. nixlab adapter (Stage A, old name; every host loads these rules today): `services.prometheus-nixlab.maintenance.alerts.features.zfsMembers = lib.mkDefault true;`. `rendered.nix` merges `cfg.maintenance.alerts.features`, so nothing else changes.
5. Write `docs/operations/zfs-metrics.md`: the six metric names, their labels (`pool`, `device`, `vdev_type`, `type`), and who must write them (a textfile `.prom` in the node_exporter textfile directory).

### 8.3 Names and labels baked into the dashboard

`system-overview-v5.json` panel 412 ("Time since each timer last fired") hard-codes your five timers: `name=~"nixos-upgrade.timer|flake-update.timer|backup-home.timer|nixlab-gpull.timer|nix-gc.timer"`. Template it the way `prometheus_url` already is:

- In the dashboard's `templating.list` add a hidden constant `{"name": "timers_regex", "type": "constant", "hide": 2, "query": "nixos-upgrade.timer|nix-gc.timer", "current": {"text": "nixos-upgrade.timer|nix-gc.timer", "value": "nixos-upgrade.timer|nix-gc.timer"}}`, and change the panel's `expr` to `time() - node_systemd_timer_last_trigger_seconds{name=~\"${timers_regex}\"}`.
- Grafana module: add `timersRegex = lib.mkOption {type = lib.types.str; default = "nixos-upgrade.timer|nix-gc.timer"; …}` and extend the existing `jq` in `grafana-provision` with a second `--arg t "${cfg.timersRegex}"` and `| (.templating.list[]? | select(.name=="timers_regex")) |= (.query=$t | .current={text:$t,value:$t})`.
- nixlab adapter (Stage A, old name): `services.grafana-nixlab.timersRegex = lib.mkDefault "nixos-upgrade.timer|flake-update.timer|backup-home.timer|nixlab-gpull.timer|nix-gc.timer";`.

The provisioned dashboard file differs textually from today (a variable and an expression), but renders the same on your hosts. Panels 431/432 (maintenance log) are discussed in §3.4: keep `lokiJob` at its default.

### 8.4 Anything else

```bash
grep -rniE 'zpool|zfs|mirror|nfs|nvidia|plasma|nixlab' modules stacks sops | grep -v '^docs'
```
From the code you sent the remaining hits are wording: the stack's `mkEnableOption "nixlab observability stack (…)"`, option descriptions mentioning "nixlab", and the `10.0.0.x` examples (§7.3). Reword them.

**Check:** `nix flake check`. The fingerprint diff against `obs-fp-0` now has **three intended differences**, all removals on the harness host that nixlab's adapter restores: `loki-ruler.json` loses the Xid rule, `prometheus.json` loses the six ZFS-member rules, and the Grafana unit's provisioning text mentions the timers variable.
**Commit:** one commit per sub-step (8.1, 8.2, 8.3).

---

## Part 9 — CI and release automation

Create three files under `.github/workflows/`. **Pin every `uses:` to a full commit SHA** (look up the current release of each action and paste its SHA; I can't know today's), the same supply-chain care you applied to flake inputs.

`ci.yml`:
```yaml
name: ci
on:
  pull_request:
  push:
    branches: [main]
permissions:
  contents: read
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<sha>
      - uses: cachix/install-nix-action@<sha>
        with:
          extra_nix_config: |
            experimental-features = nix-command flakes
            system-features = nixos-test benchmark big-parallel kvm
      - name: Enable KVM
        run: |
          echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' | sudo tee /etc/udev/rules.d/99-kvm4all.rules
          sudo udevadm control --reload-rules
          sudo udevadm trigger --name-match=kvm
      - run: nix flake check --print-build-logs
      - run: nix build .#vm-smoke --print-build-logs
      - name: Example builds against this checkout
        run: nix build ./examples/minimal#nixosConfigurations.demo.config.system.build.toplevel --override-input observability "path:$PWD" --no-link
```
`release.yml` (a tag creates a GitHub release; final tags *require* a changelog section):
```yaml
name: release
on:
  push:
    tags: ['v*']
permissions:
  contents: write
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<sha>
      - uses: cachix/install-nix-action@<sha>
      - run: nix flake check
      - name: Release notes
        run: |
          v="${GITHUB_REF_NAME#v}"
          case "$v" in
            *-rc*) echo "Release candidate $v. Not for production." > notes.md ;;
            *) awk -v v="$v" '$0 ~ "^## " v "( |$)" {f=1; next} /^## / {f=0} f' CHANGELOG.md > notes.md
               test -s notes.md || { echo "CHANGELOG.md has no section for $v"; exit 1; } ;;
          esac
      - name: Publish
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          flag=""; case "$GITHUB_REF_NAME" in *-rc*) flag="--prerelease" ;; esac
          gh release create "$GITHUB_REF_NAME" --title "$GITHUB_REF_NAME" --notes-file notes.md $flag
```
`update-flake-lock.yml` (weekly PR; CI proves the update before you merge it):
```yaml
name: update-flake-lock
on:
  schedule: [{cron: "0 5 * * 1"}]
  workflow_dispatch:
permissions:
  contents: write
  pull-requests: write
jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<sha>
      - uses: cachix/install-nix-action@<sha>
      - uses: DeterminateSystems/update-flake-lock@<sha>
        with:
          token: ${{ secrets.FLAKE_UPDATE_TOKEN }}   # a PAT or app token: PRs made with GITHUB_TOKEN do NOT trigger ci.yml
```
Then in GitHub **Settings → Branches**, protect `main`: require the `check` job, require PRs.

**Check:** push the branch and open a PR to `main`: `check` runs green, including `vm-smoke`. If the VM test hangs on KVM, the udev step didn't take; look for `/dev/kvm` in the job log. If the runner runs out of disk, add a "free disk space" step before the build.
**Commit:** `git add -A && git commit -m "ci: checks, vm smoke, release and lock-update workflows"`

---

## Part 10 — Release v0.3.0 and move nixlab over

### 10.0 What your automation will do to this migration (read first)

I read the three modules in `hosts/common/automation/`. They shape how every step of this part must be done:

| Module | What it does | Consequence for you |
|---|---|---|
| `flake-update` (every host, 23:40 + up to 1 h) | `git pull --rebase` in `~/nixlab`, then **`nix flake update`** (all inputs), commits `flake.lock`, **`git push`** | A checkout of a feature branch gets a lock-wide update commit and a push attempt. Any parity measurement that spans midnight also contains nixpkgs movement. A tag in `flake.nix` survives `nix flake update`; a lock edited with `--override-input` **does not** (the input is re-resolved from `flake.nix`). So **always edit the `url` in `flake.nix`** (Guide 2 §10.1 used an override: don't repeat that). |
| `nixlab-gpull` (hourly) | `git pull --rebase` in `~/nixlab` | It will rebase whatever branch is checked out there. |
| `nixos-upgrade` (02:00 ± 30 min) | builds **`github:Temhr/nixlab`** (i.e. `main`) with `--no-write-lock-file`, `operation = "boot"`, **`allowReboot = true`** | Merging to `main` rolls the change to **every host the same night**, with a reboot. And a canary activated from a branch is **replaced by `main` at 02:00**, so a multi-day canary is impossible without the pins below. |

**Canary recipe.**
1. Use a separate checkout, never `~/nixlab`: `git clone git@github.com:Temhr/nixlab.git ~/nixlab-canary && cd ~/nixlab-canary && git switch obs-evolve`.
2. In that branch's `hosts/nixvat.nix` (a QEMU guest, which makes it a good canary), inside the `hosts--nixvat` module, add the pins. That module's arguments are `{config, inputs, pkgs, ...}`, so add `lib`:
   ```nix
   # CANARY PINS: remove in the commit that precedes the merge to main.
   system.autoUpgrade.enable = lib.mkForce false;           # else 02:00 puts main back
   systemd.timers.flake-update.enable = lib.mkForce false;  # else it runs `nix flake update` on the canary
   systemd.timers.nixlab-gpull.enable = lib.mkForce false;
   ```
3. Deploy with `sudo nixos-rebuild switch --flake ~/nixlab-canary#nixvat` (use `test` only for the first dry run; `test` does not survive the reboot you need to prove).
4. Because `main` stays on the old config until you merge, **the staged rollout (canary → other channel → `nixnas1`) is done the same way, host by host, each with the three pins**, and only then do you remove the pins, merge, and let the remaining hosts upgrade overnight. Plan the reboot window.

### 10.1 Release candidate

```bash
cd $OBS
nix flake check --print-build-logs && nix build .#vm-smoke
git push -u origin evolve                  # CI green on the PR
git tag v0.3.0-rc1 && git push origin v0.3.0-rc1
```

### 10.2 nixlab Stage A: bump (old names, via aliases) plus three adapter lines

```bash
cd $NIXLAB
sed -i 's#observability/v0.2.0"#observability/v0.3.0-rc1"#' flake.nix
nix flake update observability
git diff --stat flake.lock                 # only the observability entry
```
Add the three adapter lines Part 8 needs, in `stacks/observability-nixlab.nix` (old names; Stage B renames them):
```nix
    services.nixlab-observability.integrations.nvidia.enable = lib.mkDefault true;                    # §8.1
    services.prometheus-nixlab.maintenance.alerts.features.zfsMembers = lib.mkDefault true;            # §8.2
    services.grafana-nixlab.timersRegex = lib.mkDefault "nixos-upgrade.timer|flake-update.timer|backup-home.timer|nixlab-gpull.timer|nix-gc.timer";   # §8.3
```
```bash
git add -A && nix flake check
for h in nixnas1 nixnas2 nixace nixsun nixtop nixvat nixzen; do
  nix build ".#nixosConfigurations.$h.config.system.build.toplevel" --no-link || echo "FAILED: $h"
done
git commit -am "chore(observability): adopt v0.3.0-rc1 via compat aliases (stage A)"
$BASELINE/capture2.sh $BASELINE/after3          # do not `git pull` between here and Stage B's measurement
for h in nixnas1 nixnas2 nixace nixsun nixtop nixvat nixzen; do nix eval --raw ".#nixosConfigurations.$h.config.system.build.toplevel.outPath"; echo; done > $BASELINE/outpaths-A.txt
diff -ru $BASELINE/before3 $BASELINE/after3 -x toplevel > $BASELINE/parity3.diff; wc -l $BASELINE/parity3.diff
```
**Expected differences** (everything else is a bug):

| Where | OK? | Note |
|---|---|---|
| `units*.json` store-path hashes | yes | normalise with `sed -E 's#/nix/store/[a-z0-9]{32}-#/nix/store/#g'` |
| `units.json` Grafana: `modules/nixos/observability/grafana/dashboards` → `modules/nixos/grafana/dashboards` | yes | flatten (5.6); the relative path only |
| `assertion-count.json` | only if you added assertions | |
| `groups.json` / `users.json` `extraGroups`, `sops-secrets.json` `restartUnits` | order only | sets must match |
| `loki-ruler.json` | **no** | if the Xid rule is missing, the `nvidia` adapter line is missing |
| `prometheus-rendered.json` | **no** | if the six ZFS-member rules are missing, the `zfsMembers` adapter line is missing |
| `alertmanager.json`, `datasources.json`, `alloy-extra.json`, `prometheus-rendered.json`, `firewall-*.json`, `tmpfiles.json` | **no** | any diff is a bug in Parts 3–8 |
| rebuild output | new | **deprecation warnings** ("option … has been renamed") for each old name nixlab sets: expected, and the reason for Stage B |

**If you see `… defined multiple times` on an option the adapter sets with `mkDefault`:** the alias dropped the priority; use `mkRenamedOptionModuleWith` (§5.8 *If it fails*).
Write the explanation to `$OBS/docs/development/migration/parity-report-3.md` and commit it in `$OBS`.

### 10.3 Canary and rollout

Follow the **canary recipe in §10.0**, then Guide 2 §12.1's checks with `v0.3.0-rc1`: `nix run github:Temhr/observability/v0.3.0-rc1#mon-check -- --fire-test` (now the **hermetic** script; with `ntfyAuth.enable = false` in your `profile-base` you do not need `MON_NTFY_AUTH`), UIDs unchanged, `id <you>` still lists the service groups, `systemctl --failed` empty, `observability-backup` run, one reboot. Soak ≥ 3 days (a backup run, an alert), then the other-channel host, then `nixnas1`.

Then: remove the canary pins, merge `evolve` in `$OBS`, tag and pin:
```bash
cd $OBS && git switch main && git merge --no-ff evolve
git tag -a v0.3.0 -m "Product-scoped names with compat aliases, flat layout, one owner per setting, vm test, generated docs"
git push origin main v0.3.0
cd $NIXLAB && sed -i 's#observability/v0.3.0-rc1"#observability/v0.3.0"#' flake.nix && nix flake update observability
git commit -am "chore(observability): pin v0.3.0"
```
Merging `obs-evolve` into nixlab `main` now is what rolls the rest of the fleet overnight (§10.0). Do it deliberately, at a time you accept every host rebooting.

### 10.4 nixlab Stage B: switch to the new names

```bash
cd $NIXLAB && git switch -c obs-names           # branch from the Stage A head; do not rebase onto a newer main yet
bash $OBS/docs/development/migration/rename-tokens.sh $MAP hosts home modules stacks flake sops
```
This rewrites the option names in `profile-base`, `profile-desktop`, `profile-nas`, `nixnas1` and the adapter. It cannot fix the adapter's **imports** (it used nixlab's own `self.nixosModules.*`, which stops existing when you delete the re-export), so replace the adapter and delete the re-export:

```nix
{inputs, self, ...}: {
  flake.nixosModules.stack--observability-nixlab = {config, lib, hostMeta ? {}, ...}: let
    obs = inputs.observability.nixosModules;
    registry = self.lib.serviceRegistry {inherit config;};
    registryTcpTargets =
      lib.mapAttrsToList (_: e: "127.0.0.1:${toString e.port}")
      (lib.filterAttrs (k: _: registry.enabled.${k} or false) (registry.endpoints or {}));
    mainUsers = let u = config.nixlab.mainUser or ""; in lib.optional (u != "") u;
  in {
    imports = [obs.stack--observability obs.nsops--observability-alertmanager obs.nsops--observability-grafana];

    services.observability = {
      publicHost = lib.mkDefault (hostMeta.address or null);
      probes.gateway = lib.mkDefault (hostMeta.gateway or null);
      probes.tcpTargets = lib.mkDefault registryTcpTargets;
      integrations.nvidia.enable = lib.mkDefault true;   # Part 11.2 narrows this
    };
    services.observability-prometheus.maintenance.alerts.features.zfsMembers = lib.mkDefault true;
    services.observability-grafana.timersRegex = lib.mkDefault "nixos-upgrade.timer|flake-update.timer|backup-home.timer|nixlab-gpull.timer|nix-gc.timer";

    services.observability-alertmanager.secretsFile = lib.mkDefault ../sops/alertmanager.env;
    services.observability-grafana.secretsFile = lib.mkDefault ../sops/grafana.yaml;

    # Plain assignment on purpose (lists merge; mkDefault would be dropped if a host set its own).
    services.observability-loki.extraUsers = mainUsers;
    services.observability-grafana.extraUsers = mainUsers;
    services.observability-alloy.extraUsers = mainUsers;
    services.observability-ntfy.extraUsers = mainUsers;
    services.observability-prometheus.extraUsers = mainUsers;
  };
}
```
```bash
git rm flake/observability.nix            # nixlab no longer re-exports the observability modules as its own
git add -A
# Any old name left? (lines mentioning stack--observability-nixlab are the adapter's own name: ignore those)
awk '{print $1}' $MAP | while read -r t; do git grep -nF -e "$t" -- hosts home modules stacks flake sops; done | grep -v 'stack--observability-nixlab'
nix flake check
for h in nixnas1 nixnas2 nixace nixsun nixtop nixvat nixzen; do nix eval --raw ".#nixosConfigurations.$h.config.system.build.toplevel.outPath"; echo; done > $BASELINE/outpaths-B.txt
diff $BASELINE/outpaths-A.txt $BASELINE/outpaths-B.txt && echo "toplevels identical"
```
**Check:** the `awk` loop prints nothing; `toplevels identical`. A pure rename produces the same store paths, which is the strongest parity there is. If they differ, run `capture2.sh` into `after-B` (it still works: the old names read through the aliases) and diff against `after3`: expect **only list-order** differences (`extraGroups`, `restartUnits`), because definition order changed. A nightly `flake-update` commit that landed in between would show up as nixpkgs differences: that is why you must not rebase between the two measurements.
**Deprecation warnings are gone** from `nixos-rebuild build`. Roll out as in 10.3 (canary pins, one host at a time), soak a week.
**Commit:** `git commit -am "refactor(observability): use product-scoped option and module names; drop re-export (stage B)"`

---

## Part 11 — Policy changes (the only deliberate behaviour changes)

**Process for every item:** its own branch in `$OBS` → patch release `v0.3.N` (CHANGELOG entry) → nixlab bump → `before`/`after` capture limited to the files the item should touch → canary (with the §10.0 pins) → fleet. Never bundle two items.

### 11.1 Network exposure, including Wi-Fi (write ADR-011)

**Facts from your code:** `profile-base` sets `access.expose = ["grafana" "ntfy" "prometheus"]` **and `notifications.ntfyAuth.enable = false`**; `profile-desktop` passes `[hostMeta.ethIface hostMeta.wifiIface]`; `profile-nas` passes the wired interface only. So on every desktop and laptop, **ntfy (anyone may read and publish alerts) and Prometheus (no authentication at all) are reachable by anyone on the Wi-Fi network**; only Grafana has a login. ADR-008 allows this ("the consumer decides") but its *Context* implies Wi-Fi is the awkward case, and the option's old text said never to do it. `$BASELINE/before3/<host>/firewall-ifaces.json` shows exactly what is open per host. From `flake/data/hosts-meta.nix`: **all seven hosts have an `ethIface`**; `nixnas1` has no Wi-Fi (`wifiIface = ""`), and `nixnas2` has a Wi-Fi device that `profile-nas` already ignores. So wired-only is feasible on every host, and there is no Wi-Fi-only machine to design for.

| Option | Effect | Cost |
|---|---|---|
| A. Keep, document | Wi-Fi stays open; write the risk into ADR-011 | none |
| B. Wired only (nixlab side) | `profile-desktop` passes only `ethIface` | a Wi-Fi-only laptop loses LAN access to its dashboards (still reachable on loopback or over an SSH tunnel) |
| C. Authenticate, then keep | `notifications.ntfyAuth.enable = true` fleet-wide (it already works: needs `NTFY_*_PASSWORD` in `sops/alertmanager.env`) and `expose = ["grafana" "ntfy"]` on Wi-Fi | secret setup; Prometheus then wired-only |

**Recommendation:** B on `nixace`, `nixsun`, `nixtop`, `nixvat` and `nixzen`; C only if a laptop is routinely used undocked on Wi-Fi. Record the decision as `ADR-011-wifi-exposure.md` (context, the table, decision, consequences) so code, option text and docs stop disagreeing.
**Implementation of B** (`profile-desktop.nix`; add `lib` to the module arguments): `services.observability.access.interfaces = lib.filter (i: i != "") [hostMeta.ethIface];`
**Test:** a `firewall-ifaces.json` diff shows **only** the Wi-Fi entries removed. On the canary, from another machine: `curl -m3 http://<wifi-ip>:3101/api/health` now fails; against the wired IP it works.

### 11.2 Narrow the Xid rule to NVIDIA hosts

```bash
for h in nixnas1 nixnas2 nixace nixsun nixtop nixvat nixzen; do
  printf '%s: ' $h; nix eval --json ".#nixosConfigurations.$h.config.services.xserver.videoDrivers"
done
```
If `nvidia` appears exactly on the hosts you expect, change the adapter line to `integrations.nvidia.enable = lib.mkDefault (builtins.elem "nvidia" config.services.xserver.videoDrivers);`. **Test:** only `loki-ruler.json` on the non-NVIDIA hosts changes (rule removed).

### 11.3 Hardening review

Your `mon-snapshot.sh` already records scores: `bin/mon-snapshot.sh /tmp/h && cat /tmp/h/security.txt` (one `systemd-analyze security` summary line per unit). Record them in `docs/security/hardening.md` (unit, score, date). Today's configuration, from the code: Prometheus, Loki, ntfy, Grafana, node_exporter and Alloy all use `extraHardening`; Alloy uses `allowJIT` and a fully visible `/proc`; node_exporter turns off `SystemCallFilter`, `ProtectClock` and `ProtectProc` on purpose (comments in the module say why); smartctl runs with `CAP_SYS_RAWIO` and `PrivateDevices = false`. The remaining room is in those documented exceptions and in `allowUnixSockets`/`RestrictAddressFamilies`. **One flag per commit**, `nixos-rebuild test`, `mon-check`, `journalctl -u <unit> -b | grep -iE 'denied|status=31|SYS'` (status 31 = a syscall filter killed it: revert that flag for that unit and write the reason beside it), re-run `vm-smoke`.

### 11.4 Backup and restore drill

What the backup unit really does: every night `observability-backup` runs `sqlite3 <db> ".backup '<dir>/<name>.bak'"` for `grafana.db`, ntfy's `cache.db` and (when auth is on) `user.db`, and `cp -a` for `/var/lib/private/alertmanager` and the maintenance log, into `/data/backup` (mode 0600, root only). Prometheus TSDB and Loki chunks are **not** backed up. Drill on the canary:
```bash
sudo systemctl start observability-backup && sudo ls -la /data/backup
sudo sqlite3 /data/backup/grafana.db.bak 'PRAGMA integrity_check;'          # ok
sudo sqlite3 /data/backup/grafana.db.bak 'select count(*) from dashboard;'
# real restore, keeping the live copy:
sudo systemctl stop grafana
sudo mv /data/grafana/data/grafana.db /data/grafana/data/grafana.db.keep
sudo cp /data/backup/grafana.db.bak /data/grafana/data/grafana.db
sudo chown grafana:grafana /data/grafana/data/grafana.db       # REQUIRED: see below
sudo systemctl start grafana && nix run github:Temhr/observability/v0.3.0#mon-check
```
The explicit `chown` matters: `grafana-permissions` is a `RemainAfterExit` oneshot, so it does **not** run again on a plain restart. Write the exact commands into `docs/operations/backup-restore.md` (Grafana, ntfy `user.db`/`cache.db`, Alertmanager silences) and repeat once on a NAS host. Also confirm `/data/backup` is in your off-host backup (`backup-home`).

### 11.5 Secret rotation

The wiki references `docs/secrets-rotation.md` and `bin/rotate-secret.sh`, which don't exist in the repo: write `docs/operations/secret-rotation.md` per secret. What the code gives you: `ALERTMANAGER_ENV` (`sops/alertmanager.env`, dotenv; keys `NTFY_ALERTMANAGER_PASSWORD`, `NTFY_READER_PASSWORD`, plus any `$VAR` used by receivers; `restartUnits` already restarts Alertmanager and, with ntfy auth on, `ntfy-provision`), and `GRAFANA_ADMIN_PASSWORD`/`GRAFANA_SECRET_KEY` (`sops/grafana.yaml`). Rotate with `sops sops/alertmanager.env`, commit, deploy, verify with `mon-check --fire-test` (reader password for `MON_NTFY_AUTH` from `/run/secrets/ALERTMANAGER_ENV`). Two traps to document: the Grafana admin password only applies to a **new** database (use `grafana cli admin reset-admin-password` afterwards), and changing `GRAFANA_SECRET_KEY` on an existing database makes stored secrets unreadable. Log each rotation: `sudo maintenance-log --section <checklist section> --task "Rotated <secret>" --status completed`.

---

## Part 12 — READMEs

### 12.1 `observability/README.md` (replace; fill the `<…>` and the licence)

The README you sent has three problems: it is HTML tags (`<h1>`, `<figure class="table">`, `<strong>`) pasted into a Markdown file, so GitHub renders much of it as literal text; it never says what the flake is called or shows a usable snippet; and **eight of its links are dead** (`docs/architecture/overview.md`, `module-boundaries.md`, `security-model.md`, `docs/operations/installation.md`, `backup-restore.md`, `troubleshooting.md`, `docs/development/testing.md`, `adding-a-component.md`) while its structure list names directories that don't exist (`lib/`, `config/`, `scripts/`, `tests/`). Replace it wholesale. Its good parts (design principles, the ownership table) are folded into the draft below.

````markdown
# observability

Prometheus, Loki, Alloy, Grafana, Alertmanager and ntfy as composable NixOS modules, with one aggregator module that wires them together: provisioned datasources, scrape jobs, alert routing, push notifications, ~60 documented alerts with runbooks, and a nightly state backup.

Extracted from [nixlab](https://github.com/Temhr/nixlab), where it still runs the author's fleet.

## Quick start

```nix
{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
  inputs.observability.url = "github:Temhr/observability/v0.3.0";   # pin a tag, never a branch
  inputs.observability.inputs.nixpkgs.follows = "nixpkgs";

  outputs = {nixpkgs, observability, ...}: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        observability.nixosModules.default
        {
          services.observability.enable = true;
          services.observability-alertmanager.environmentFile = "/run/secrets/alertmanager.env";
          services.observability-grafana.credentialsFile = "/run/secrets/grafana-admin";
          services.observability-grafana.secretKeyFile = "/run/secrets/grafana-secret-key";
        }
      ];
    };
  };
}
```
Services bind to loopback. To reach them from the network: `services.observability.access.interfaces = ["eth0"];`. A complete example is in [`examples/minimal`](examples/minimal/flake.nix).

## Modules

| Module | Purpose |
|---|---|
| `stack--observability` (= `default`) | the whole stack, wired together |
| `servc--observability-{prometheus,alertmanager,ntfy,loki,alloy,grafana}` | one service each, usable alone |
| `systm--observability-{host-exporters,maintenance-log,backup}` | supporting capabilities |
| `nsops--observability-{alertmanager,grafana}` | **optional** [sops-nix](https://github.com/Mic92/sops-nix) wiring |

Importing a module starts nothing; each has an `enable`. Modules can be imported together or individually in any combination.

## What you must provide

Only `enable`, plus secret *paths* for Alertmanager and Grafana (any secret manager works; sops-nix is optional). Host prerequisites (documented, not enforced): the data directory (default `/data`) is mounted before the stack starts; time sync reaches `time-sync.target`; journald; nginx only if a service sets `domain`.

## Documentation

- [Options reference](docs/reference/options.md) (generated)
- [Public API and stability](docs/architecture/public-api.md) · [Decisions (ADRs)](docs/architecture/decisions/)
- [Operations](docs/operations/) · [Alert runbooks](docs/runbooks/) · [Extending](docs/development/extending.md)

## Testing

`nix flake check` validates rendered Prometheus/Alertmanager/Loki/Alloy configs, rule unit tests, runbook coverage, dashboards, scripts and contract tests on three fake machines (stable, unstable, a consumer without sops-nix). `nix build .#vm-smoke` boots a VM with the stack and checks every endpoint (needs KVM). Helper scripts: `nix run .#mon-check`, `.#mon-snapshot`, `.#mon-unitdiff`.

## Versioning

Pre-1.0: a minor release may break; see [CHANGELOG](CHANGELOG.md). Deprecated names keep working for one minor release and warn.

## Licence

<licence>
````

### 12.2 `nixlab/README.md`: exact edits

The README you showed me predates the extraction (it still lists `modules/nixos/observability/`, `stacks/observability.nix`, `docs/runbooks/`, `bin/mon-*.sh`, `flake/ci/observability-checks.nix`; its docs link `docs/observability/observability.md` was already stale). Edits:

| README location | Change |
|---|---|
| Intro paragraph | Keep "Running the observability stack? Start at Observability Stack", but say it now lives in its own flake. |
| *Module Naming* table, `servc--` / `stack--` / `systm--` rows | Say these exist for nixlab's **own** services; the observability modules come from the `observability` input, not `self.nixosModules`. Keep `stack--observability-nixlab` as the one adapter. |
| *Dendritic Pattern* item 2 (Stacks) | `stacks/` now holds the adapter; the example of a "real" stack is the observability flake's aggregator. |
| *Entry Point* `import-tree` comment for `./modules` and `./stacks` | Drop "flake.lib hooks for CI"; stacks → "nixlab adapters". |
| *Self-Registration* last paragraph ("Modules may also register `flake.lib` hooks for CI") | Delete the observability examples; the hooks (`prometheusRendered`, …) are the observability flake's. |
| *Coupling Principles*, "Single source of truth" bullet | The registry is consumed by the **adapter** (`probes.tcpTargets`), not the stack. |
| *Secrets Management* | `nsops--alertmanager/grafana` now come from the observability flake; nixlab keeps the encrypted files and sets `secretsFile` in the adapter. Replace the "stack may consume" sentence accordingly. |
| *Repository Layout* tree | Remove `modules/nixos/observability/`, `stacks/observability.nix`, `docs/observability/`, `docs/runbooks/`, `bin/mon-*.sh`, `flake/ci/observability-checks.nix`, `_tests/`. Add `flake/ci/observability-integration.nix`, `stacks/observability-nixlab.nix`, `docs/wiki/`, `docs/migration/`. |
| *Top-Level Folder Reference*: `flake/` table | Replace the `observability-checks.nix` row with `observability-integration.nix` (runs the observability flake's host checks against real nixlab hosts). Delete the *Known exception* paragraph about Prometheus importing host-exporters. |
| *Top-Level Folder Reference*: `docs/`, `bin/` | `docs/` = wiki + migration guides only; `bin/` no longer lists `mon-*`. |
| *Daily Commands* | `nix flake check` comment: "eval + pre-commit + observability integration checks". Replace `bin/mon-check.sh` with `nix run github:Temhr/observability/v0.3.0#mon-check`. |
| *Adding a New Service Module* §4 | "Make it observable": add a scrape job via `services.observability-prometheus.extraScrapeConfigs`; for an alert or dashboard that is generally useful, contribute it to the observability repo (its `docs/development/extending.md`). |
| *Observability Stack* section | Replace with the text below. |

Replacement section:

````markdown
## Observability Stack

Monitoring (Prometheus, Loki, Alloy, Grafana, Alertmanager, ntfy) is **no longer part of this repository**. It is its own flake, [Temhr/observability](https://github.com/Temhr/observability), consumed as a pinned input (`inputs.observability`, a release tag). Its architecture, options reference and alert runbooks live there.

nixlab owns one **adapter**, `stacks/observability-nixlab.nix` (`stack--observability-nixlab`), imported by `hosts--profl--base`. It translates nixlab facts into the stack's options:

| nixlab fact | Becomes |
|---|---|
| `hostMeta` address and gateway | `services.observability.publicHost`, `probes.gateway` |
| the homepage service registry | `probes.tcpTargets` |
| `sops/alertmanager.env`, `sops/grafana.yaml` | `secretsFile` of the optional `sops-*` modules |
| `nixlab.mainUser` | `extraUsers` on each service (read access to data directories) |
| NVIDIA hosts | `integrations.nvidia.enable` |

**Profiles** enable the stack on every host (`profile-base`) and set per-role exposure and mounts (`profile-desktop`, `profile-nas`). **Per-host overrides:**
```nix
services.observability.access.interfaces = [ "eno1" ];
services.observability-prometheus.maintenance.expectedMounts = [ "/data" ];
services.observability-grafana.extraDashboards = [ "zfs-monitoring" ];   # ZFS host only
```
**Operating:** `nix run github:Temhr/observability/<tag>#mon-check` (add `-- --fire-test` for an end-to-end alert).
**Upgrading:** change the tag in `flake.nix`, `nix flake lock --update-input observability`, read the observability CHANGELOG, `nix flake check`, build all hosts, canary one with `nixos-rebuild test`, then roll out. The tag is pinned so the auto-update modules cannot move it.
````

Also copy all three guides into `nixlab/docs/migration/` (`obs-01-…`, `obs-02-…`, `obs-03-…`).

**Check (both repos):** `docs-links` green in the observability repo; in nixlab `grep -rn "docs/runbooks\|modules/nixos/observability\|stacks/observability.nix\|mon-check.sh" README.md` prints nothing.
**Commit:** one commit per repo: `docs: README for the extracted flake` / `docs(readme): observability lives in its own flake`.

---

## Part 13 — Contract, then 1.0

### 13.1 v0.4.0: delete the compatibility layer

Only after nixlab has been on the new names for at least a week (Stage B):

```bash
cd $OBS && git switch -c drop-compat
git rm -r compat
# remove: (inputs.import-tree ./compat) from flake.nix; self.nixosModules.compat-options from the stack's imports
git grep -n "compat" -- . ':!docs/development' ':!CHANGELOG.md'         # prints nothing
```
CHANGELOG: `## 0.4.0 — Removed: all names deprecated in 0.3.0.` Also edit your `capture2.sh` to the new option names (it reads `services.loki-nixlab…`, `grafana-nixlab…`, `alloy-nixlab…` through the aliases until now). Run `nix flake check`, `vm-smoke`, tag `v0.4.0`, bump nixlab, canary, roll out. Rewrite the "Deprecated names" table in `public-api.md` into a short "Migrating from 0.2/0.3" note.

### 13.2 What "1.0" means (all must be true)

- [ ] A release has shipped with no compat layer for at least one minor version, and nixlab runs it.
- [ ] `docs/reference/options.md` has **no option without a description** (flip `warningsAreErrors = true` in `flake/ci/docs.nix`).
- [ ] `vm-smoke` green on stable **and** unstable nixpkgs in CI.
- [ ] Restore drill (11.4) done and written up; rotation runbook (11.5) exists.
- [ ] A person (or a fresh VM) builds `examples/minimal` from the README alone.
- [ ] `public-api.md` states the semver policy; deprecation = one minor with a warning.
- [ ] `_todo.txt` is empty (every alert has a runbook).
- [ ] Hardening table (11.3) recorded; exceptions explained.

### 13.3 Deliberately not in this guide

Windows/Darwin support (modules are Linux-only), a multi-host or federated Prometheus design (each host is self-contained by design), dashboards beyond the three that exist, and a binary cache for the checks. Each is a feature, not a migration step.

---

## Progress checklist

- [ ] 0.1 entry gate (+ LICENSE, .gitignore, guides copied into nixlab)
- [ ] 1.2 v0.2.1 hotfix + adapter reconciled and soaked · 1.3 branches, tag, `before3`, `outpaths-before.txt`
- [ ] 2 safety net green: ports, loki runbooks, loki/alloy config, golden, vm-smoke, fingerprint baseline
- [ ] 3.1 aliases removed · 3.2 ports · 3.3 paths · 3.4 Loki label
- [ ] 4 keys (double-import green)
- [ ] 5 ADR-010 written · rename map · rename · flatten · compat generated · all compat checks green
- [ ] 6 hermetic scripts
- [ ] 7 docs split/scrubbed/generated; public API v0.3; CHANGELOG
- [ ] 8 nvidia gated
- [ ] 9 workflows, branch protection
- [ ] 10.1 rc · 10.2 stage A parity (`parity-report-3.md`) · 10.3 canary, v0.3.0 · 10.4 stage B identical toplevels
- [ ] 11.1 exposure/Wi-Fi (ADR-011) · 11.2 Xid · 11.3 hardening · 11.4 restore drill · 11.5 rotation
- [ ] 12 both READMEs
- [ ] 13.1 v0.4.0

---

## Appendix A — Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `already declared in` the same file twice | A module lacks its `keyed` wrapper (Part 4), or something imports a file by path instead of by name. |
| `option … does not exist` for an old name | The alias list is stale or missing that option; rebuild `compat/option-aliases.json` from the **pre-rename** dump (5.4/5.7) and re-run `compat-alias-targets`. |
| Both `["eth0","eth1"]` in `alias-priority` | The alias lost priority; use `mkRenamedOptionModuleWith` (5.8). |
| `legacy` lists lines after the rename | Nested-attribute spelling the script can't see, or a legitimate state path; review each (5.5). |
| `port-defaults` fails after deleting `ports.nix` | An option default differs from the old `mkDefault`; set the default to the `want` value (3.2). |
| `golden-domain-effects` fails | Behaviour changed. If intended: `nix build .#goldens -o /tmp/g && cp -L /tmp/g/*.json flake/ci/_golden/`, and mention it in the CHANGELOG. |
| `options-doc-fresh` fails | `nix build .#options-doc -o /tmp/o && cp -L /tmp/o docs/reference/options.md`. |
| `loki -verify-config` fails on `${…}` | Config uses env placeholders; add `-config.expand-env=true`. |
| `mon-check` build fails in shellcheck / `unbound variable` | The script ran under `set -u` for the first time; quote and default variables (6.3). |
| VM test: `unit … not found` | Real unit name differs; take it from `units.json` in your baseline. |
| CI can't open `/dev/kvm` | The udev step is missing or ordered after the build (Part 9). |
| Flake-lock PR doesn't trigger CI | It was created with `GITHUB_TOKEN`; use a PAT/app token (Part 9). |
| nixlab Stage B toplevels differ | Usually list order. Compare `capture2.sh` outputs; only `extraGroups`/`restartUnits` order may differ (10.4). |
| Completely stuck | `git stash`, run the last passing Check, re-apply one edit at a time. |

## Appendix B — Where every hand-off item went

| Item (Guide 1 App. B / Guide 2 hand-off) | Handled in |
|---|---|
| Rename + flatten with aliases | Part 5 (+ 13.1 removal) |
| Ports triplicated | 3.2 |
| Wi-Fi policy | 11.1 + ADR-011 |
| Final names | Part 5 + ADR-010 |
| Automation hazards (new) | 10.0 |
| Loki's hard-coded job label | 3.4 |
| Hard-coded `/var/lib/private/alertmanager`, `/var/lib/node_exporter` | 3.3 |
| nginx/firewall side effects | 2.4 (pinned), 7.6 (documented) |
| Loki-ruler tests/runbooks; Loki/Alloy validation | 2.2, 2.3 |
| Hermetic scripts | Part 6 |
| Split/scrub docs | Part 7 |
| ZFS/NVIDIA/host-table scrub | 7.3, Part 8, 11.2 |
| Hardening, backup/restore, rotation, release automation | 11.3, 11.4, 11.5, Part 9 |
| READMEs for both repos | Part 12 |
| Double-import footgun (new) | Part 4 |

## Appendix C — Still unseen (send these if a step fails or you want it tightened)

- **Observability repo:** `flake/ci/_tests/prometheus/rules.test.yml` (to confirm §8.2 doesn't break a rule test); `docs/architecture/public-api.md` as it stands (you sent the 0.2 text, which I used).
- **nixlab:** the code that produces the `zfs_*` metrics (`hardware/common/mounts/zfs-*.nix` and the `zfs-member-reconcile` script), to write `docs/operations/zfs-metrics.md` accurately; `flake/builders/hosts.nix` / `mkHostMeta` (does `hostMeta.gateway` exist? §1.2).
- **Results:** the output of the §1.2 commands, and the first failing Check of any part.
