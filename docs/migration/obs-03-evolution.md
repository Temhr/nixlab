# Observability Flake — Guide 3 of 3: Evolution

> **Goal:** turn the decoupled flake (v0.2.0) into a product other people could use: neutral names, a flat layout, one owner for every setting, stronger tests (including a real VM boot), generated and scrubbed docs, release automation, and READMEs for both repos. Policy changes (Wi-Fi exposure, hardening, secret rotation) come **last and one at a time**, because they are the only steps meant to change what your hosts do.
>
> **Order of work:** safety net first (Part 2), then structure (Parts 3–9), then ship and prove parity (Part 10), then deliberate behaviour changes (Part 11), then READMEs (Part 12).
>
> **Revision 4: edit cards.** Every file edit is now introduced by a card that names the file, the repo, the action and the exact place in the file (see "How to read an edit"), and every command block says where to run it. Part 2 has a map of `observability-checks.nix` with named landing spots.
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

### How to read an edit (the one rule used everywhere)

Every change to a file is introduced by an **edit card** directly above the code block:

> 📝 **Edit `path/to/file`** · repo `$OBS` or `$NIXLAB` · **create a new file** / **replace the whole file** / **add …** / **delete …** / **edit in place**
> **Where:** exactly where in the file the change goes, named by something you can search for (a line, an attribute, a block).

Rules that go with it:
- **Never paste a snippet anywhere except the file on its card.** Names such as `toJson`, `hosts`, `harness` or `allFeatures` exist only inside the file the card names; pasting into another file fails with `undefined variable`.
- In a block, a line starting with `-` is removed, a line starting with `+` is added, and `…` means "the existing code here stays". Do not type the `-`, `+` or `…`.
- Command blocks start with `# run in: <where>`: `$OBS` is the observability repo, `$NIXLAB` the nixlab repo, otherwise a named machine. If a block begins with `cd`, that line is the answer.
- "Create a new file" blocks are the **whole** file. "Replace the whole file" means delete the old contents first.
- In these repos a bare `nix fmt` waits for input on stdin; always give it a path: `nix fmt -- .` (your `nfmt` alias does this).
- If an edit has a landmark ("directly under `// {`"), search the file for that exact text; if you cannot find it, **stop and send me that file** rather than guessing.

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
  # run in: $OBS
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

> 📝 **Edit `~/obs-env.sh`** · repo `your home directory` · **append to the file**
> **Where:** at the end, after the existing lines.
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
# run in: a nixlab host, as your user
id temhr | tr ',' '\n' | grep -E 'loki|prometheus|grafana|ntfy|alloy'     # you will see none, or fewer than five
grep -c 'blackbox-icmp' /data/prometheus/prometheus.yml                     # 0 if the gateway probe is missing
```

**Step 1: failing test (observability repo, branch off `main`).** In `flake/ci/_harness/default.nix`, add these lines at the top level of `fullStack` (before `services.nixlab-observability = {…}`):
> 📝 **Edit `flake/ci/_harness/default.nix`** · repo `$OBS` · **add 6 lines**
> **Where:** inside `fullStack = { … };`, as its first lines: directly after the line `fullStack = {` and above `services.nixlab-observability = {`.
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
> 📝 **Edit `two files, named in the `# path` comment that starts each hunk`** · repo `$OBS` · **edit one line in each**
> **Where:** in each file the `-` line is removed and the `+` line takes its place; nothing else in the file changes. Alloy: inside `users.users = lib.mkMerge ( … )` in the module's `config`. Prometheus: the same `users.users = lib.mkMerge ( … )` expression in `config.nix`.
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
> 📝 **Edit `stacks/observability-nixlab.nix`** · repo `$NIXLAB` · **replace the whole file**
> **Where:** delete everything in the file and paste this.
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
# run in: $NIXLAB
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

### 2.0 Map of `flake/ci/observability-checks.nix` (read this once)

Most Part 2 snippets are pasted into **this one file**, and only at four named places. The skeleton below shows the file as it is today, with the four **landing spots** marked. Everything else in the file stays as it is.

> 📝 **Orientation only** · nothing to paste yet. Open `flake/ci/observability-checks.nix` in `$OBS` and find these landmarks.

```nix
{self, inputs, lib, ...}: {
  perSystem = {pkgs, system, ...}: let
    inherit (self.lib) prometheusMaintenanceAlerts;
    toJson = name: value: pkgs.writeText name (builtins.toJSON value);   # defined HERE, nowhere else
    tools = [ … ];
    allFeatures = { traefik = true; … };
    harness = import ./_harness {inherit inputs self;};
    hosts = {
      stable = …;
      unstable = …;
      external = …;
      minimal = …;
      alias = …;
      # >>> SPOT B: a new host entry goes here (after `minimal`, or after `alias`)
    };
    # >>> SPOT A: a new `let` binding goes here (after `hosts = {…};`, before `in`)
  in {
    # >>> SPOT C: a new top-level attribute goes here (packages.* …), above `checks =`
    checks = lib.optionalAttrs (system == "x86_64-linux") (
      (lib.foldl' (acc: name: acc // self.lib.observabilityHostChecks { … }) {} ["stable" "unstable" "external"])
      // {
        # >>> SPOT D: a new check goes here, directly under this `// {` line
        alias-alloyport = …;      # (removed later by §3.1)
        runbook-url-consistent = …;
        …
      }
    );
  };
}
```
Each card in Part 2 says which spot (A, B, C or D) it uses. **Do not paste check, host or package snippets into any module file** (`alloy/default.nix`, `loki/default.nix`, …): `toJson`, `hosts` and `harness` are not defined there.

### 2.1 Pin the port numbers

Part 3 deletes `ports.nix`; this test proves no number moves. Values come from Guide 1 §3.4.

> 📝 **Edit `flake/ci/observability-checks.nix`** · repo `$OBS` · **add one check**
> **Where:** the **checks landing spot (D)** of `flake/ci/observability-checks.nix`, §2.0: a new entry inside the `checks` attrset, directly under the `// {` line
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

> 📝 **Edit `flake/ci/observability-checks.nix`** · repo `$OBS` · **add one check**
> **Where:** the **checks landing spot (D)** of `flake/ci/observability-checks.nix`, §2.0: a new entry inside the `checks` attrset, directly under the `// {` line
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

Today CI validates Prometheus and Alertmanager only. Loki's config is built *inside* `preStart` (`lokiConfig`) and Alloy's inside the module's `let` (`baseAlloyConfig`), so CI cannot see either. Move each expression out **unchanged** and register it the way Prometheus does (`flake.lib.prometheusRendered`). Five steps, each a separate edit card; the checks (step 5) go in a **different file** from steps 1–4.

#### 2.3.1 Loki: create `rendered.nix`

> 📝 **Edit `modules/nixos/observability/loki/_internals/rendered.nix`** · repo `$OBS` · **create a new file**
> **Where:** new file. Cut the **whole right-hand side** of `lokiConfig =` out of `loki/default.nix` (everything from the `{` that opens `auth_enabled = false;` through the closing `}` of `// lib.optionalAttrs cfg.ruler.enable { ruler = {…}; }`, but not the trailing `;`), and paste it under the first line below.
```nix
{cfg, lib}:
{
  auth_enabled = false;
  # … everything else from the old lokiConfig, unchanged …
}
// lib.optionalAttrs cfg.ruler.enable {
  ruler = {…};
}
```

#### 2.3.2 Loki: use it and register it

> 📝 **Edit `modules/nixos/observability/loki/default.nix`** · repo `$OBS` · **two edits**
> **Where, edit 1:** inside `systemd.services.loki = { … preStart = let … in ''…''; }`, the binding `lokiConfig = { … } // lib.optionalAttrs … ;` (now empty because you cut it) becomes the single line below.
```nix
            lokiConfig = import ./_internals/rendered.nix {inherit cfg lib;};
```
> **Where, edit 2:** at the top of the file, in the outer attrset `{self, ...}: { … }`, add this attribute **above** `flake.nixosModules.servc--loki-nixlab = …` (sibling of it, not inside it).
```nix
  flake.lib.lokiRendered = {config, lib}:
    import ./_internals/rendered.nix {cfg = config.services.loki-nixlab; inherit lib;};
```

#### 2.3.3 Alloy: create `rendered.nix` (you have done this)

> 📝 **Edit `modules/nixos/observability/alloy/_internals/rendered.nix`** · repo `$OBS` · **create a new file**
> **Where:** new file whose first line is `{cfg, hostName}: ''` followed by the old `baseAlloyConfig` text, ending in `'';`. In the text, `${config.networking.hostName}` becomes `${hostName}` in three places (the journal source's `labels`, the `systemd` process stage, the `varlogs` process stage).

#### 2.3.4 Alloy: use it and register it (you have done this)

> 📝 **Edit `modules/nixos/observability/alloy/default.nix`** · repo `$OBS` · **two edits, and nothing else**
> **Where, edit 1:** in the module's `let`, `baseAlloyConfig = ''…'';` becomes `baseAlloyConfig = import ./_internals/rendered.nix {inherit cfg; hostName = config.networking.hostName;};`.
> **Where, edit 2:** in the outer attrset, above `flake.nixosModules.servc--alloy-nixlab = …`, add:
```nix
  flake.lib.alloyRendered = {config, ...}: let
    cfg = config.services.alloy-nixlab;
  in
    (import ./_internals/rendered.nix {inherit cfg; hostName = config.networking.hostName;}) + cfg.extraConfig;
```
> **Nothing about `loki-config` or `alloy-config` belongs in this file.** If you pasted them here (the `undefined variable 'toJson'` error), delete those two `runCommand` bindings from the module's `let`; they go in step 5.

#### 2.3.5 The two checks (a different file)

> 📝 **Edit `flake/ci/observability-checks.nix`** · repo `$OBS` · **add two checks**
> **Where:** the **checks landing spot (D)** of `flake/ci/observability-checks.nix`, §2.0: a new entry inside the `checks` attrset, directly under the `// {` line. `toJson`, `hosts` and `self` are in scope there.
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
(`hosts.stable` has the maintenance pipeline enabled, so the appended Alloy section is validated too. `alloy fmt` is the safe syntax gate; if `nix run nixpkgs#grafana-alloy -- --help` also lists `validate`, add it as a second step.)

**Check:** both build. **Prove they can fail:** temporarily delete a closing `}` in `alloy/_internals/rendered.nix`, see red, revert. Because this is a pure move, `nix build .#checks.x86_64-linux.toplevel-stable --no-link` must still pass and the fingerprint (§2.6) must not change.
**If you see `undefined variable 'toJson'` (or `hosts`, `harness`):** the check snippet is in the wrong file. It must be in `flake/ci/observability-checks.nix`, never in a module.

### 2.4 Pin the nginx/firewall side effects (golden file)

Guide 1 Appendix B #5: five modules switch on nginx and open firewall ports when `domain` is set. That is public behaviour nobody has recorded. A *golden file* records it; the check fails if it ever changes unnoticed.

1. Add a harness host with domains set. In `observability-checks.nix`, inside `hosts = { … };`:
   > 📝 **Edit `flake/ci/observability-checks.nix`** · repo `$OBS` · **add one host**
   > **Where:** the **`hosts` landing spot (B)** of `flake/ci/observability-checks.nix`, §2.0: a new entry inside `hosts = { … };`, after the `minimal = …;` entry
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
   > 📝 **Edit `flake/ci/observability-checks.nix`** · repo `$OBS` · **add one binding**
   > **Where:** the **`let` landing spot (A)** of `flake/ci/observability-checks.nix`, §2.0: a new binding after `hosts = { … };`, before `in {`
   ```nix
    domainEffects = let c = hosts.domain.config; in {
      nginxEnabled = c.services.nginx.enable;
      vhosts = builtins.attrNames c.services.nginx.virtualHosts;
      firewallTcp = c.networking.firewall.allowedTCPPorts;
      failingAssertions = map (a: a.message) (lib.filter (a: !a.assertion) c.assertions);
    };
   ```
   > 📝 **Edit `flake/ci/observability-checks.nix`** · repo `$OBS` · **add one package**
   > **Where:** the **top-level landing spot (C)** of `flake/ci/observability-checks.nix`, §2.0: a new attribute directly under `in {`, above `checks =`
   ```nix
    packages.goldens = pkgs.linkFarm "goldens" [
      {name = "domain-effects.json"; path = toJson "domain-effects.json" domainEffects;}
    ];
   ```
   and the check:
   > 📝 **Edit `flake/ci/observability-checks.nix`** · repo `$OBS` · **add one check**
   > **Where:** the **checks landing spot (D)** of `flake/ci/observability-checks.nix`, §2.0: a new entry inside the `checks` attrset, directly under the `// {` line
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
   # run in: $OBS
   mkdir -p flake/ci/_golden && git add -A
   nix build .#goldens -o /tmp/g && cp -L /tmp/g/domain-effects.json flake/ci/_golden/ && git add -A
   cat flake/ci/_golden/domain-effects.json
   ```
**Check:** the JSON shows `nginxEnabled: true` and your two vhosts. **Read `failingAssertions`:** if it is non-empty the harness is missing something (for example an SSL setting); add it to the `domain` host until it is `[]`, then regenerate. (`_golden/` starts with `_`, so import-tree ignores it.)

### 2.5 The VM smoke test (the one real boot)

Eval-time checks can't catch "starts, then crashes". Create `flake/ci/vm-smoke.nix`:

> 📝 **Edit `flake/ci/vm-smoke.nix`** · repo `$OBS` · **create a new file**
> **Where:** new file; paste the whole block.
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
# run in: $OBS
git add -A
nix build .#packages.x86_64-linux.vm-smoke --print-build-logs
```
It boots a VM and passes in a few minutes. **If it fails,** the log shows which `curl` failed; run `nix build … --keep-failed` or add `machine.shell_interact()` temporarily to look around. A failure here on the *unchanged* v0.2.0 code is a real finding; fix the test or the module before refactoring.

### 2.6 A fingerprint for fast parity

Comparing all seven nixlab hosts after every small change is slow. This package dumps the parts of the harness host that matter (units, users, firewall, tmpfiles, rendered configs, secrets wiring) so you can diff before/after in seconds. In `observability-checks.nix`, in the `perSystem` attrset next to `packages.goldens`:

> 📝 **Edit `flake/ci/observability-checks.nix`** · repo `$OBS` · **add one package**
> **Where:** the **top-level landing spot (C)** of `flake/ci/observability-checks.nix`, §2.0: a new attribute directly under `in {`, above `checks =`. It defines its own `let`, so it needs nothing else from the file except `hosts`, `self`, `lib` and `pkgs`, which are in scope there
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
# run in: $OBS
nix fmt -- . && git add -A
for t in port-defaults loki-runbook-coverage golden-domain-effects loki-config alloy-config; do
  echo "== $t"; nix build ".#checks.x86_64-linux.$t" --no-link --print-build-logs || echo "FAILED: $t"
done
nix flake check --print-build-logs
```
**Check:** no `FAILED:`, `nix flake check` green.

**Commit:**
```bash
# run in: $OBS
git add -A && git commit -m "test: characterization net (ports, loki runbooks, loki/alloy config, domain side effects, vm smoke)"
```

---

## Part 3 — One owner per setting

Four refactors plus one tidy-up, **one commit each**, all behaviour-preserving. After each: `nix flake check`, then `fp $BASELINE/obs-fp-N && diff -ru $BASELINE/obs-fp-0 $BASELINE/obs-fp-N` (commit first; `fp` needs a clean tree). **Expected diff: none**, unless the step says otherwise.

### 3.1 Remove the 0.2 compatibility aliases

Guide 2 §6 marked them `# Remove in 0.3`, and no nixlab host sets those options.

In `stacks/observability.nix`, delete these six lines from `imports`:
> 📝 **Edit `stacks/observability.nix`** · repo `$OBS` · **delete 6 lines**
> **Where:** they are the last six lines inside `imports = [ … ];` (after `self.nixosModules.systm--observability-backup-nixlab`). The `];` that closes the list stays.
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
# run in: $OBS
grep -rn "systm--ports" modules stacks sops flake
```
**Do:**
1. **Edit five files** (repo `$OBS`): `modules/nixos/observability/{ntfy,loki,grafana,prometheus,alertmanager}/default.nix` (Alloy has no ports module, so leave it). In each, find the line `self.nixosModules.systm--ports-<name>` inside the module's `imports = [ … ];` list and delete that line. For ntfy, loki, grafana and alertmanager the list is then empty, so delete the whole `imports = [ … ];` statement; in `prometheus/default.nix` the list still holds `self.nixosModules.systm--host-exporters-nixlab`, which stays. The `self` argument stays (`obsLib = self.lib.obsLib;` uses it).
2. `git rm modules/nixos/observability/ports.nix`
3. Two stale comments in `stacks/observability.nix`: change *"Single source of truth: ports.nix (mkDefault) or a plain assignment in a host file."* to *"Single source of truth: each service's option default, or a plain assignment in a host file."*, and *"Ports are never set here; see ports.nix / host plain assignment."* to *"Ports are never set here."*
4. `git add -A && nix build .#checks.x86_64-linux.port-defaults --no-link`

**If `port-defaults` fails:** each mismatch is an option whose own `default` differed from the `ports.nix` value that used to win. Set that option's `default` to the `want` number. I compared `ports.nix` with every option default in the modules you sent and **all eleven values already agree** (ntfy 2586; Loki 3100/9096; Grafana 3101; Prometheus 9090/9115/9633/9558; Alertmanager 9093/9094; Alloy's 12345 is only an option default), so expect green with no default edits.
**nixlab side:** `cd $NIXLAB && git grep -nE 'systm--ports-(ntfy|loki|grafana|prometheus|alertmanager)'` must print nothing.
**Precedence afterwards:** host plain assignment **>** option default. The `mkDefault` middle tier is gone from this flake.
**Commit:** `git commit -am "refactor(ports): option defaults are the single owner; drop systm--ports-*"`

### 3.3 Hard-coded state paths

The node_exporter textfile directory `/var/lib/node_exporter` is a literal in **four** places: `stacks/observability.nix` (the maintenance-log `textfileDir`), `prometheus/_internals/config.nix` (a tmpfiles rule, and the bridge `nodeExporter.textfileDir = lib.mkIf cfg.maintenance.enable "/var/lib/node_exporter"`), and `prometheus/_internals/exporters/maintenance.nix` (`METRICS_DIR="/var/lib/node_exporter"` in the backup-exporter script). The owner is `host-exporters` (`nodeExporter.textfileDir`); Prometheus' bridge is the one place that chooses the value. Everyone else reads it.

> 📝 **Edit `three files, named in the `# path` comment that starts each hunk`** · repo `$OBS` · **edit in place**
> **Where:** each hunk shows the file and the lines around the change; `-` lines are removed, `+` lines added. Hunk 1: inside `services.maintenance-log-nixlab = { … };` in the stack. Hunk 2: inside the `systemd.tmpfiles.rules` list in `prometheus/_internals/config.nix`. Hunk 3: inside the script text in `prometheus/_internals/exporters/maintenance.nix`.
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
> 📝 **Edit `stacks/observability.nix`** · repo `$OBS` · **replace the first list element**
> **Where:** inside `services.observability-backup-nixlab = { … };`, in the `plainFiles = [ … ];` list: the `-` line is replaced by the `+` lines; the `svc.maintenance-log-nixlab.logPath` element stays.
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
   > 📝 **Edit `modules/nixos/observability/maintenance-log/default.nix`** · repo `$OBS` · **add one option**
   > **Where:** inside `options.services.maintenance-log-nixlab = { … };`, after the `textfileDir` option.
   ```nix
      lokiJob = lib.mkOption {
        type = lib.types.str;
        default = "maintenance-log";
        description = "Value of the Loki `job` label for this log. Consumers that ship the file must label it with this. The bundled system-overview dashboard (panels 431 and 432) queries the default value.";
      };
   ```
2. **Loki option.** Add the option:
   > 📝 **Edit `modules/nixos/observability/loki/default.nix`** · repo `$OBS` · **add one option**
   > **Where:** inside `options.services.loki-nixlab = { … };` (note: `options`, not the rendered config), after the `openGrpcFirewall` option.
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
   Then replace the literal `retention_stream = [ {selector = ''{job="maintenance-log"}''; priority = 1; period = "17520h";} ];` inside `limits_config` by closing `limits_config` and appending:
   > 📝 **Edit `modules/nixos/observability/loki/_internals/rendered.nix`** · repo `$OBS` · **edit the `limits_config` entry**
   > **Where:** in the attrset you moved there in §2.3: delete the `retention_stream = [ … ];` list from inside `limits_config = { … }`, and append the `// lib.optionalAttrs …` expression after `limits_config`'s closing `}`.
   ```nix
                limits_config = { …everything except retention_stream… }
                  // lib.optionalAttrs (cfg.retentionStreams != []) {
                    retention_stream = map (s: {inherit (s) selector priority period;}) cfg.retentionStreams;
                  };
   ```
3. **Stack** (`stacks/observability.nix`, repo `$OBS`): two edits. First, in the `services.loki-nixlab = {…};` block add
   > 📝 **Edit `stacks/observability.nix`** · repo `$OBS` · **add one attribute**
   > **Where:** inside `services.loki-nixlab = { … };`, after the `retention = lib.mkDefault cfg.loki.retention;` line.
   ```nix
        retentionStreams = [
          {
            selector = ''{job="${svc.maintenance-log-nixlab.lokiJob}"}'';
            priority = 1;
            period = "17520h";
          }
        ];
   ```
   Second, in the same file, in the `let` binding `maintenanceAlloyConfig = ''…'';`, inside `stage.static_labels { values = { … } }`, change the line `job  = "maintenance-log",` to `job  = "${svc.maintenance-log-nixlab.lokiJob}",`.

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

> 📝 **Edit `flake/ci/contract-checks.nix`** · repo `$OBS` · **create a new file**
> **Where:** new file; paste the whole block.
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
# run in: $OBS
git add -A
nix build .#checks.x86_64-linux.double-import --no-link 2>&1 | grep -m2 "error\|already declared"
```
**Check (success = failure):** `already declared in …`.

### 4.3 Add the helper

In `flake/lib/obs-lib.nix`, inside the `flake.lib.obsLib = { … }` attrset add:

> 📝 **Edit `flake/lib/obs-lib.nix`** · repo `$OBS` · **add one attribute**
> **Where:** inside `flake.lib.obsLib = { … };`, as the first attribute (directly under the opening line).
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
> 📝 **Edit `modules/nixos/observability/loki/default.nix`** · repo `$OBS` · **PATTERN, shown BEFORE the change**
> **Where:** this is the current shape of every module file in the table below; nothing to paste yet.
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
> 📝 **Edit `every file in the table below (shown on `loki/default.nix`)`** · repo `$OBS` · **edit 2 places per file**
> **Where:** (1) the line `flake.nixosModules.<name> = {` becomes `flake.nixosModules.<name> = self.lib.obsLib.keyed "<key>" ({`; (2) the module's closing `};` (the very last line before the outer `}`) becomes `});`. The module body in between is untouched (let `nix fmt` re-indent).
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
# run in: $OBS
nix fmt -- . && git add -A
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
> 📝 **Edit `docs/architecture/decisions/ADR-010-final-names.md`** · repo `$OBS` · **create a new file**
> **Where:** new file; paste the whole block.
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

> 📝 **Edit `docs/development/migration/rename-map.txt`** · repo `$OBS` · **create a new file**
> **Where:** new file; paste the whole block (two columns, old then new, separated by spaces).
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

> 📝 **Edit `docs/development/migration/rename-tokens.sh`** · repo `$OBS` · **create a new file**
> **Where:** new file; paste the whole block, then `chmod +x` it.
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

> 📝 **Edit `compat/checks.nix`** · repo `$OBS` · **create a new file (and a new directory `compat/`)**
> **Where:** new file; paste the whole block.
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
and **also edit `flake.nix`** (repo `$OBS`): in the `imports = [ … ];` list of the `mkFlake` call, add the line `(inputs.import-tree ./compat)` next to the other `(inputs.import-tree …)` lines.

```bash
# run in: $OBS
git add -A
nix build .#checks.x86_64-linux.compat-names --no-link 2>&1 | grep -m1 -i "error\|missing"
```
**Check (success = failure):** red. **From here until §5.7 is done, `nix flake check` is expected to fail** with `Path 'compat/option-aliases.json' does not exist` (the `compat-alias-targets` check reads a file §5.7 creates); that is the intended red state, not a mistake. Commit the red state: `git commit -m "test: compatibility contract (intentionally failing)"`.

### 5.4 Dump the old option paths (before renaming!)

Temporarily add to `observability-checks.nix`'s `perSystem` (**do not commit this edit**):

> 📝 **Edit `flake/ci/observability-checks.nix`** · repo `$OBS` · **add one package, TEMPORARILY (do not commit)**
> **Where:** the **top-level landing spot (C)** of `flake/ci/observability-checks.nix`, §2.0: a new attribute directly under `in {`, above `checks =`
```nix
    packages.option-paths = let
      prefixes = ["nixlab-observability" "prometheus-nixlab" "alertmanager-nixlab" "ntfy-nixlab" "loki-nixlab" "alloy-nixlab" "grafana-nixlab" "host-exporters-nixlab" "maintenance-log-nixlab" "observability-backup-nixlab"];
      leaves = lib.concatMap (p: map (o: o.loc) (lib.collect lib.isOption hosts.stable.options.services.${p})) prefixes;
    in toJson "option-paths.json" leaves;
```
```bash
# run in: $OBS
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
nix fmt -- . && git add -A
git diff --stat | tail -3
legacy | head -40
```
Add one tiny file so `default` exists, `stacks/default.nix`:
> 📝 **Edit `stacks/default.nix`** · repo `$OBS` · **create a new file**
> **Where:** new file; paste the one-line block.
```nix
{self, ...}: {flake.nixosModules.default = self.nixosModules.stack--observability;}
```
**Review every line `legacy` still prints.** Expect three kinds:

1. **Aliased bindings** (the common one): code that reads options through a short name, such as `svc = config.services;` then `svc.grafana-nixlab.port`, or `s = hosts.minimal.config.services;` then `s.ntfy-nixlab.port`. The script only rewrites the full `services.<x>-nixlab` spelling, so these remain. Rename them with this command (repo `$OBS`), which touches only the two files that use such bindings:
   ```bash
   # run in: $OBS
   perl -pi -e 's/\b(svc|s)\.(prometheus|alertmanager|ntfy|loki|alloy|grafana|host-exporters|maintenance-log)-nixlab\b/$1.observability-$2/g; s/\b(svc|s)\.observability-backup-nixlab\b/$1.observability-backup/g' stacks/observability.nix flake/ci/observability-checks.nix
   ```
   If `legacy` shows such a binding in another file, add that file to the command.
2. **Comments and descriptions** that mention a placeholder such as `services.<x>-nixlab.*`: edit by hand.
3. **Legitimate leftovers**: a state path, unit name or file name that happens to contain `-nixlab`, and the check named `no-nixlab-coupling` (it is the check that enforces the absence of nixlab coupling). Leave these.

**Never** rename a unit, user or directory (E2).

**Check:** `legacy | wc -l` is 0, or every remaining line is explained in your commit message.
**Commit:** `git commit -am "refactor: neutral module and option names (aliases follow in 5.8)"`

### 5.6 Flatten the layout (a pure move: no edits in this commit)

```bash
cd $OBS
for s in prometheus alertmanager ntfy loki alloy grafana host-exporters maintenance-log; do
  git mv modules/nixos/observability/$s modules/nixos/$s
done
git mv modules/nixos/observability/observability-backup modules/nixos/backup     # (if yours ended up as modules/nixos/observability-backup, that works too; only the key `observability:backup` matters)
ls modules/nixos                       # eight service dirs + backup, no observability/
git commit -m "refactor(layout): flatten modules/nixos/<service>"
```
Then fix what moved, in a *separate* commit:
```bash
# run in: $OBS
grep -rn '\.\./\|modules/nixos/observability' modules stacks sops flake docs/architecture examples
```
Most imports are same-directory (`./_internals/…`, `./dashboards`) and need nothing. Fix any hit that crosses a service directory. One known string, in `modules/nixos/grafana/default.nix` (inside the `assertions` entry about `extraDashboards`): the message says `modules/nixos/observability/grafana/dashboards/`; change it to `modules/nixos/grafana/dashboards/`.
**Check:** `nix flake check` and `nix build .#checks.x86_64-linux.toplevel-stable --no-link` green; `fp $BASELINE/obs-fp-5 && diff -ru $BASELINE/obs-fp-0 $BASELINE/obs-fp-5` shows **only** lines where a path changed from `modules/nixos/observability/<svc>` to `modules/nixos/<svc>` (the Grafana dashboards directory). Nothing else.
**Commit:** `git commit -am "refactor(layout): fix relative references after flatten"`

### 5.7 Generate the compatibility layer

**(a) Old module names → new modules** (generated, deprecated, deleted in 0.4.0):
```bash
# run in: $OBS
mkdir -p compat
{
  echo '# Deprecated pre-0.3 module names. Removed in 0.4.0 — migrate to the names in docs/architecture/public-api.md.'
  echo '{self, ...}: {'
  echo '  flake.nixosModules = {'
  awk 'NF==2 && $1 !~ /^services\./ { extra = ($1 ~ /^nsops--/) ? " self.nixosModules.compat-sops-options" : ""; printf "    %s = {imports = [self.nixosModules.%s self.nixosModules.compat-options%s];};\n", $1, $2, extra }' $MAP
  echo '  };'
  echo '}'
} > compat/module-names.nix
```
Importing an old name also pulls in the option aliases (the two old `nsops--` names also pull in `compat-sops-options`, see below); Part 4's keys make the double import a no-op. If you already generated this file with the earlier command, run this block again: it overwrites `compat/module-names.nix`.

**(b) Old option names → new options** (per leaf, E3). Build the alias list from the dump in 5.4:
```bash
# run in: $OBS
jq --argjson m "$(awk -F' +' 'BEGIN{printf "{"} $1 ~ /^services\./ {o=$1; n=$2; sub(/^services\./,"",o); sub(/^services\./,"",n); printf "%s\"%s\":\"%s\"", sep, o, n; sep=","} END{printf "}"}' $MAP)" \
  '[ .[] | {old: ., new: ([.[0], $m[.[1]]] + .[2:])} ]' compat/old-option-paths.json > compat/option-aliases.json
jq -e 'all(.[]; .new | all(. != null))' compat/option-aliases.json     # prints true
```
`compat/options.nix`. **Two modules, not one:** the `secretsFile` options are declared only by the *optional* sops modules, and NixOS fails with *"The option … does not exist"* if an alias module defines a target that a host did not import. So the two `secretsFile` aliases ride on the old `nsops--` names instead of on the stack.

> 📝 **Edit `compat/options.nix`** · repo `$OBS` · **create a new file, or replace it if you already created it**
> **Where:** the whole file; paste the whole block.
```nix
{
  self,
  lib,
  ...
}: let
  aliases = builtins.fromJSON (builtins.readFile ./option-aliases.json);
  # Options declared only by the optional sops modules (nsops--observability-*).
  isSops = a: lib.last a.new == "secretsFile";
  mkAliases = as: map (a: lib.mkRenamedOptionModule a.old a.new) as;
in {
  # Imported by the stack, so every consumer of the stack gets these.
  flake.nixosModules.compat-options = self.lib.obsLib.keyed "observability:compat-options" {
    # Deprecated pre-0.3 option names; each use prints a warning. Removed in 0.4.0.
    imports = mkAliases (lib.filter (a: !(isSops a)) aliases);
  };

  # Imported only by the OLD nsops--alertmanager / nsops--grafana names (see compat/module-names.nix).
  flake.nixosModules.compat-sops-options = self.lib.obsLib.keyed "observability:compat-sops-options" {
    imports = mkAliases (lib.filter isSops aliases);
  };
}
```
If you generated `compat/module-names.nix` with the earlier command, re-run the awk block above (it now adds `compat-sops-options` to the two `nsops--…` lines), or edit those two lines by hand so they read:
```nix
    nsops--alertmanager = {imports = [self.nixosModules.nsops--observability-alertmanager self.nixosModules.compat-options self.nixosModules.compat-sops-options];};
    nsops--grafana = {imports = [self.nixosModules.nsops--observability-grafana self.nixosModules.compat-options self.nixosModules.compat-sops-options];};
```
**Also edit `stacks/observability.nix`** (repo `$OBS`): in its `imports = [ … ];` list add `self.nixosModules.compat-options` as the last element.

### 5.8 Check

```bash
# run in: $OBS
nix fmt -- . && git add -A
for t in compat-names compat-alias-targets alias-priority old-style-consumer double-import toplevel-stable toplevel-external toplevel-minimal; do
  echo "== $t"; nix build ".#checks.x86_64-linux.$t" --no-link --print-build-logs || echo "FAILED: $t"
done
nix build ./examples/minimal#nixosConfigurations.demo.config.system.build.toplevel --override-input observability "path:$PWD" --no-link
nix flake check --print-build-logs
```
**If several checks fail with `The option \`services.observability-alertmanager.secretsFile' does not exist … In compat/options.nix`:** `compat-options` still contains the two `secretsFile` aliases. Use the two-module `compat/options.nix` above. (Hosts with the sops modules, such as `stable`, pass; hosts without them, such as `external`, `minimal` and the examples, fail, which is the tell-tale.)
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

> 📝 **Edit `flake/ci/apps.nix`** · repo `$OBS` · **replace the whole file**
> **Where:** delete everything in the file and paste this.
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

### 6.3 Make the build pass (three steps)

**What is going on.** The first build after 6.2 is *expected* to fail. `writeShellApplication` runs `shellcheck` on each script, and shellcheck's "info"-level notes count as failures. Your build reported exactly two kinds of note:

| Code | Where | What it means | Safe here? |
|---|---|---|---|
| `SC2015` | `mon-check` (4 places: the `[ … ] && ok … \|\| bad …` lines and the `cu -XPOST … && ok … \|\| bad …` line) | "`A && B || C` is not if-then-else: `C` can run when `A` is true". It matters only if `B` can fail. | **Yes.** `B` is `ok`, which is only a `printf` and cannot fail. |
| `SC2035` | `mon-unitdiff` (2 places: `ls *.service *.timer`) | "a file name starting with `-` would be read as an option" | **Yes.** The glob runs inside a directory of unit files, whose names never start with `-`. |
| (none) | `mon-snapshot` | clean | |

So the fix is to tell the build that these two codes are acceptable for these two scripts. You do **not** need to edit the scripts.

**Step 1: edit three lines in `flake/ci/apps.nix`.**

> 📝 **Edit `flake/ci/apps.nix`** · repo `$OBS` · **replace 2 lines**
> **Where:** inside `scripts = { … };`. The `mon-check` line and the `mon-unitdiff` line are replaced; the `mon-snapshot` line stays exactly as it is. Search the file for `mon-check = mk` and `mon-unitdiff = mk`.
```nix
      mon-check = mk {name = "mon-check"; file = ../../bin/mon-check.sh; exclude = ["SC2015"];};
      mon-unitdiff = mk {name = "mon-unitdiff"; file = ../../bin/mon-unitdiff.sh; extra = [pkgs.diffutils]; exclude = ["SC2035"];};
```

**Step 2: rebuild.** Success is **no output at all** from this command:
```bash
# run in: $OBS
git add -A && nix build .#mon-check .#mon-snapshot .#mon-unitdiff --no-link --print-build-logs 2>&1 | grep -E 'SC[0-9]+|error'
```
If a different `SCnnnn` code now appears (shellcheck can reveal a second layer once the first is excluded), look it up in the output, decide whether it is safe in the same way, and add it to **that script's** `exclude = [ … ]` list, e.g. `exclude = ["SC2015" "SC2045"];`. If you would rather fix a script than exclude a code, send me the line and I will give you the exact rewrite.

**Step 3: prove the scripts run.** `mon-check` is read-only; it prints one `OK`/`FAIL` line per check and then exits. On a machine without the stack running, `FAIL` lines are normal. What you are proving is that **no line says `command not found`**.
```bash
# run in: $OBS
nix run .#mon-check 2>&1 | head -n 12
env -i PATH=/run/current-system/sw/bin "$(nix build .#mon-check --no-link --print-out-paths)/bin/mon-check" 2>&1 | head -n 12
```
The second command runs the script with a nearly empty `PATH`, so it can only use the tools packaged with it (plus `systemctl` from the system path). It should print the same kind of lines. (Use `head -n 12`: on your system `head -12` is not accepted.)

**Commit:** `git commit -am "feat(scripts): hermetic mon-check, mon-snapshot, mon-unitdiff (packages + apps)"`
Run the real thing on the canary in Part 10.

---

## Part 7 — Docs: split, scrub, generate

### 7.1 Target layout

> 📝 **Orientation only** · nothing to paste: the target `docs/` layout, created as you move files in 7.2.
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
# run in: $OBS
git rm docs/wiki/observability.md
```

### 7.3 Scrub nixlab-specific content

```bash
# run in: $OBS
git grep -nE '10\.0\.0\.|Temhr/nixlab|nixnas|nixace|nixsun|nixtop|nixvat|nixzen|zb17|zb15|m720q|hosts--profl' -- . ':!docs/development/migration' ':!CHANGELOG.md'
```
Replace each hit with a neutral example (`192.0.2.x`, `host-a`) or delete it. (Examples already in the code that hit: the `externalUrl` option examples in Alertmanager, Grafana, ntfy and Prometheus use `10.0.0.251` and `10.0.0.10`; the first is your `nixnas1`.) The migration guides legitimately mention your hosts; that folder stays out of the scrub (if you ever go public, read it first). Runbooks that mention ZFS/NVMe/SMART as hardware examples are fine.
**Check:** the `grep` prints nothing.

### 7.4 Generated options reference

`flake/ci/docs.nix`:
> 📝 **Edit `flake/ci/docs.nix`** · repo `$OBS` · **create a new file**
> **Where:** new file; paste the whole block.
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
# run in: $OBS
mkdir -p docs/reference && git add -A
nix build .#options-doc -o /tmp/o && cp -L /tmp/o docs/reference/options.md && git add -A
grep -c '^## ' docs/reference/options.md
grep -m3 'Declared by' -A2 docs/reference/options.md      # repo-relative paths, not /nix/store
```
If "Declared by" shows store paths, adjust the `removePrefix` so it matches `toString self`. Options without a description now show up as gaps; closing them is a Part 13 criterion. (Compat aliases declared at old names are excluded by the `ours` prefix test and are `visible = false` anyway.)

### 7.5 Link check

In the `checks` block of `flake/ci/observability-checks.nix`:
> 📝 **Edit `flake/ci/observability-checks.nix`** · repo `$OBS` · **add one check**
> **Where:** the **checks landing spot (D)** of `flake/ci/observability-checks.nix`, §2.0: a new entry inside the `checks` attrset, directly under the `// {` line
```nix
        docs-links = pkgs.runCommand "docs-links" {nativeBuildInputs = [pkgs.lychee];} ''
          cd ${self}
          lychee --offline --no-progress README.md docs
          touch $out
        '';
```
(`lychee --help` should list `--offline`; if not, replace this with a `grep`-based relative-link test.) The split in 7.2 is where broken links come from.

### 7.6 Update the public contract

`docs/architecture/public-api.md` in your repo is the 0.2 text with a partly broken rename (for example `servc--observability--{…}` with a double dash, `services.observability.<name>.enable` where the real option is `services.observability-<name>.enable`, and the two sops modules still under their old names). Replace it with the version below. It also adds what 0.2 never wrote down: the module-key guarantee, the side effects of `domain`, the state and identity contract, the alert and dashboard interface, the deprecated-name tables, and the 0.3 breaking changes.

> 📝 **Edit `docs/architecture/public-api.md`** · repo `$OBS` · **replace the whole file**
> **Where:** delete everything in the file and paste the whole block. (The same text is also supplied as the file `public-api.md`.) If you skipped Part 8 (opt-in NVIDIA and ZFS alerts, `timersRegex`), delete those rows from the "Breaking" and "Added" tables.

````markdown
# Public API (v0.3)

## Stability

Pre-1.0: a minor release may break. Everything not listed under **Public** is internal. A name that is renamed keeps working, with a warning for options, for one minor release (see [Deprecated names](#deprecated-names)). Design decisions behind the names are in [ADR-010](decisions/ADR-010-final-names.md).

## Public

### NixOS modules (the names are the contract)

Exported as `observability.nixosModules.<name>`. Importing a module never starts anything; each has an `enable`. Modules can be imported alone, together, or through the stack, in any combination (see [Module keys](#module-keys)).

| Module | Purpose | Enabled by |
|---|---|---|
| `stack--observability` (also exported as `default`) | the whole stack, wired together | `services.observability.enable` |
| `servc--observability-prometheus` | metrics, rules, blackbox exporter | `services.observability-prometheus.enable` |
| `servc--observability-alertmanager` | routing, inhibition, receivers | `services.observability-alertmanager.enable` |
| `servc--observability-ntfy` | push notification server | `services.observability-ntfy.enable` |
| `servc--observability-loki` | log store and LogQL ruler | `services.observability-loki.enable` |
| `servc--observability-alloy` | log shipper | `services.observability-alloy.enable` |
| `servc--observability-grafana` | dashboards | `services.observability-grafana.enable` |
| `systm--observability-host-exporters` | node and smartctl exporters | `services.observability-host-exporters.nodeExporter.enable` and `.smartctl.enable` (the Prometheus module sets them from its own options) |
| `systm--observability-maintenance-log` | maintenance log, CLI and metrics | `services.observability-maintenance-log.enable` |
| `systm--observability-backup` | nightly copies of service state | `services.observability-backup.enable` |
| `nsops--observability-alertmanager`, `nsops--observability-grafana` | **optional** [sops-nix](https://github.com/Mic92/sops-nix) wiring | act when the service is enabled; need `secretsFile` |

### Option namespaces

| Namespace | Owner |
|---|---|
| `services.observability` | the stack (aggregator): `enable`, `listenAddress`, `publicHost`, `access.*`, `probes.*`, `openFirewall`, `dataDir`, `loki.*`, `prometheus.*`, `ntfy.*`, `notifications.*`, `integrations.*` |
| `services.observability-<component>` | one per service module above, e.g. `services.observability-loki` |

Every documented option is public: its name, type and meaning. The complete list, with defaults and descriptions, is generated from the code in [`../reference/options.md`](../reference/options.md). An option that is not in that reference is internal.

### Flake outputs

| Output | Status |
|---|---|
| `nixosModules.*` | public (above) |
| `packages.<system>.{mon-check,mon-snapshot,mon-unitdiff}` and the matching `apps` | public; command-line interface and exit codes are stable |
| `lib.observabilityHostChecks` | supported for consumers' CI (nixlab uses it), but its argument set may change in a minor release |
| everything else under `packages`, `checks`, `lib` | internal (see [Internal](#internal-no-promise)) |

### State and service identity

Persistent paths, unit names and users are part of the contract: a release does not move data or rename a unit. `<dataDir>` is `services.observability.dataDir` (default `/data`).

| Item | Value |
|---|---|
| State directories | `<dataDir>/prometheus`, `<dataDir>/loki`, `<dataDir>/grafana`, `<dataDir>/ntfy`, `<dataDir>/backup`; `/var/lib/alloy`; `/var/lib/private/alertmanager`; `/var/lib/node_exporter/*.prom` (textfile metrics); `/var/log/maintenance.jsonl` |
| Systemd units | `prometheus`, `loki`, `alloy`, `grafana`, `alertmanager`, `ntfy`, `ntfy-provision`, `prometheus-node-exporter`, `prometheus-smartctl-exporter`, `observability-backup`, `maintenance-log-metrics`, plus `<service>-permissions` and `<service>-wal-recover` helpers |
| Users (stack-pinned uid) | `loki` 740, `alloy` 741, `grafana` 742, `prometheus` 743, `ntfy` 744; Alertmanager runs with `DynamicUser` |
| Default ports | Prometheus 9090, Alertmanager 9093 (gossip 9094, off unless peers are set), Grafana 3101, Loki 3100 (gRPC 9096, loopback), ntfy 2586, Alloy 12345 (loopback), node 9100, smartctl 9633, blackbox 9115, systemd exporter 9558 |

Port precedence: a host's plain assignment beats the option default. There are no per-service port modules.

### Alerting and dashboard interface

What consumers route, silence and link to is stable. Expressions and thresholds are not.

- **Alert names.** Each Prometheus and Loki-ruler alert has a runbook at `docs/runbooks/<AlertName>.md`; renaming or removing an alert is a breaking change.
- **Alert labels.** `severity` (`warning` or `critical`), `category`, `checklist_section`, and the `host` external label. The `condition` label and the `runbook` annotation are generated.
- **Notification topics.** `<notifications.ntfyTopic>` (default `alerts`) and one `<ntfyTopic>-<name>` per entry in `notifications.topics`.
- **Datasource uids** (dashboards reference them): `prometheus`, `loki`, `alertmanager`. **Dashboard uids:** `system-maintenance-overview-v5`, `zfs-pool-monitoring`.
- **Log labels** produced by Alloy: `job` (`systemd-journal`, `varlogs`, `maintenance-log`), `host`, `unit`, `level`, `transport`.

### Secret interface

No module references a secret manager. Secrets are **file paths**: `services.observability-alertmanager.environmentFile`, `services.observability-grafana.credentialsFile` and `.secretKeyFile`, `services.observability.notifications.ntfyAuth.environmentFile`. The optional `nsops--observability-*` modules declare the sops secrets and set these paths from `secretsFile`. The repository contains no secret material.

## Guarantees

### Module keys

Every public module carries a stable `key`, so NixOS applies it once however it is reached: importing `servc--observability-loki` and `stack--observability` together is valid and does not declare options twice.

### Side effects of `domain`

Setting `services.observability-<component>.domain` enables nginx and adds a virtual host for that domain that proxies to the service; `enableSSL` additionally requests a certificate (ACME) and forces HTTPS. When that service's `openFirewall` is true it opens ports **80 and 443** instead of the service port. With the stack, per-service `openFirewall` follows `services.observability.openFirewall` (default `false`). This behaviour is pinned by a test, so a change to it is a breaking change.

### Maintenance log label

`services.observability-maintenance-log.lokiJob` (default `maintenance-log`) is the Loki `job` label of the maintenance log. The stack uses it for Alloy's label and for Loki's two-year retention stream, and the bundled system-overview dashboard queries the default value.

## Consumer-supplied (no defaults that assume your environment)

- A default install works but emits the warning `services.observability-grafana: secretKeyFile is not set…` until `services.observability-grafana.secretKeyFile` is set.
- If ntfy auth is on (`services.observability.notifications.ntfyAuth.enable`): `notifications.ntfyAuth.environmentFile`, which defaults to `services.observability-alertmanager.environmentFile`.
- If you use the `nsops--observability-*` modules: `services.observability-alertmanager.secretsFile` and `services.observability-grafana.secretsFile`, and sops-nix configured with a key source.
- If you want remote access: `services.observability.access.interfaces` (default: loopback only). Interface names must be non-empty.
- Optional context: `services.observability.publicHost`, `services.observability.probes.{gateway,icmpTargets,tcpTargets}`, and `services.observability-<component>.extraUsers` (users who get read access to a service's data).

## Host prerequisites (documented, not enforced)

The state root (`dataDir`, default `/data`, with `/data/<service>` below it) is mounted before the stack starts; time sync reaches `time-sync.target`; journald is running; nginx is needed only if a service sets `domain`; a firewall is needed only if you use `access.interfaces` or `openFirewall`. The optional ZFS alerts need the textfile metrics described in [`../operations/zfs-metrics.md`](../operations/zfs-metrics.md).

## Internal (no promise)

`self.lib.obsLib` (including `keyed`), `self.lib.{prometheusRendered,prometheusMaintenanceAlerts,lokiRendered,alloyRendered,grafanaDashboards,maintenanceLoggerScript}`, everything under `_internals/`, the test harness, the `compat` modules (`compat-options`, `compat-sops-options`; deprecated shims, removed in 0.4.0), and the development outputs (`packages.vm-smoke`, `packages.options-doc`, `packages.goldens`, `packages.fingerprint`, `checks.*`).

## Deprecated names

Deprecated in 0.3.0 and **removed in 0.4.0**. Old **option** names keep working and print a warning when used; old **module** names keep working without a warning (a flake output cannot warn). Migrate by replacing the left column with the right.

### Module names

| Old (0.2) | New |
|---|---|
| `servc--prometheus-nixlab` | `servc--observability-prometheus` |
| `servc--alertmanager-nixlab` | `servc--observability-alertmanager` |
| `servc--ntfy-nixlab` | `servc--observability-ntfy` |
| `servc--loki-nixlab` | `servc--observability-loki` |
| `servc--alloy-nixlab` | `servc--observability-alloy` |
| `servc--grafana-nixlab` | `servc--observability-grafana` |
| `systm--host-exporters-nixlab` | `systm--observability-host-exporters` |
| `systm--maintenance-log-nixlab` | `systm--observability-maintenance-log` |
| `systm--observability-backup-nixlab` | `systm--observability-backup` |
| `nsops--alertmanager` | `nsops--observability-alertmanager` |
| `nsops--grafana` | `nsops--observability-grafana` |

`stack--observability` is unchanged.

### Option namespaces

Every option under an old namespace maps to the same option under the new one (for example `services.loki-nixlab.retention` is now `services.observability-loki.retention`).

| Old (0.2) | New |
|---|---|
| `services.nixlab-observability` | `services.observability` |
| `services.prometheus-nixlab` | `services.observability-prometheus` |
| `services.alertmanager-nixlab` | `services.observability-alertmanager` |
| `services.ntfy-nixlab` | `services.observability-ntfy` |
| `services.loki-nixlab` | `services.observability-loki` |
| `services.alloy-nixlab` | `services.observability-alloy` |
| `services.grafana-nixlab` | `services.observability-grafana` |
| `services.host-exporters-nixlab` | `services.observability-host-exporters` |
| `services.maintenance-log-nixlab` | `services.observability-maintenance-log` |
| `services.observability-backup-nixlab` | `services.observability-backup` |

## Changes in 0.3

### Breaking

| Change | What to do |
|---|---|
| Module and option names (above) | rename; the old names work until 0.4.0 |
| The NVIDIA Xid log alert (`NvidiaXid`) is **opt-in**; it used to be always on | set `services.observability.integrations.nvidia.enable = true;` on hosts with the NVIDIA driver |
| The six ZFS member and scrub alerts (`ZpoolDeviceErrors`, `ZpoolDataErrors`, `ZpoolScrubOverdue`, `ZpoolScrubErrors`, `ZpoolMemberMissing`, `ZpoolMemberReonlined`) are **opt-in**; they used to load whenever maintenance alerts were on | set `services.observability-prometheus.maintenance.alerts.features.zfsMembers = true;` and provide the textfile metrics |
| A standalone Loki (without the stack) no longer applies the two-year retention to `{job="maintenance-log"}` by default | the stack sets it through `services.observability-loki.retentionStreams`; standalone users set it themselves |
| The dashboard's "Time since each timer last fired" panel filters on `services.observability-grafana.timersRegex`, default `nixos-upgrade.timer\|nix-gc.timer` | set `timersRegex` to the timers you want shown |
| The 0.2 aliases `loki-nixlab.{enableAlloy,alloyPort,alloyPackage}` and `loki-nixlab.maintenance.{enable,logPath}` are removed | use `services.observability-alloy.{enable,port,package}` and `services.observability-maintenance-log.{enable,logPath}` |

### Fixed

`services.observability-alloy.extraUsers` and `services.observability-prometheus.extraUsers` failed evaluation in 0.2.0 (fixed in 0.2.1).

### Added

`default` module; stable module keys; options `services.observability-loki.retentionStreams`, `services.observability-maintenance-log.lokiJob`, `services.observability.integrations.nvidia.enable`, `services.observability-prometheus.maintenance.alerts.features.zfsMembers`, `services.observability-grafana.timersRegex`; hermetic `mon-check`, `mon-snapshot`, `mon-unitdiff` packages.

### Internal (not API)

Per-service port modules (`systm--ports-*`) are gone; ports are option defaults with the same values. The repository layout is flattened to `modules/nixos/<service>/`.

## History: breaking changes in 0.2

Names are as they were in 0.2; see [Deprecated names](#deprecated-names) for today's.

| Change | Replacement | Alias? |
|---|---|---|
| The flake no longer reads `nixlabLib`, `hostMeta`, `allHosts`, `config.nixlab.mainUser` | the options below | n/a (never public) |
| `probes.hosts`, `probes.tcpFromRegistry` removed | `probes.icmpTargets`, `probes.tcpTargets` | no |
| `loki-nixlab.{enableAlloy,alloyPort,alloyPackage}` | `alloy-nixlab.{enable,port,package}` | removed in 0.3 |
| `loki-nixlab.maintenance.{enable,logPath}` | `maintenance-log-nixlab.{enable,logPath}` | removed in 0.3 |
| The stack no longer imports `nsops--*` | import them yourself | no |
| `secretsFile` has no default | set it | no |
| `mainUser` no longer gets implicit access | set `extraUsers` | no |
| `publicHost` and `probes.gateway` default to `null` | set them | no |
| New option `prometheus-nixlab.runbookBaseUrl` | | n/a |
| New option `notifications.ntfyAuth.environmentFile` | | n/a |
| New assertion: no empty names in `access.interfaces` | | n/a |
````

`CHANGELOG.md`:
> 📝 **Edit `CHANGELOG.md`** · repo `$OBS` · **add a section**
> **Where:** at the top, directly under the title line, above the previous release's section.
```markdown
## 0.3.0
### Breaking
- Option and module names are product-scoped (ADR-010). The old names are deprecated and keep working until 0.4.0 (options warn).
- The NVIDIA Xid log alert is opt-in: `services.observability.integrations.nvidia.enable`.
- The six ZFS member and scrub alerts are opt-in: `services.observability-prometheus.maintenance.alerts.features.zfsMembers`.
- A standalone Loki no longer gets the 2-year `{job="maintenance-log"}` retention by default; the stack sets it via `retentionStreams`.
- The dashboard's timers panel filters on `services.observability-grafana.timersRegex` (default `nixos-upgrade.timer|nix-gc.timer`).
- Removed the 0.2 aliases `loki-nixlab.{enableAlloy,alloyPort,alloyPackage}` and `loki-nixlab.maintenance.*`.
### Deprecated (removed in 0.4.0)
- All `-nixlab` option names and module names (see docs/architecture/public-api.md).
### Added
- `default` module; stable module keys; hermetic `mon-*` packages.
- Options: `services.observability-loki.retentionStreams`, `services.observability-maintenance-log.lokiJob`, `services.observability.integrations.nvidia.enable`, `services.observability-prometheus.maintenance.alerts.features.zfsMembers`, `services.observability-grafana.timersRegex`.
- Checks: `port-defaults`, `loki-config`, `alloy-config`, `loki-runbook-coverage`, `golden-domain-effects`, `double-import`, `options-doc-fresh`, `docs-links`, compat checks; `vm-smoke` package.
### Internal
- Ports are option defaults (the `systm--ports-*` modules are gone); layout flattened to `modules/nixos/<service>/`.
```
**Check / Commit:**
```bash
# run in: $OBS
nix fmt -- . && git add -A && nix flake check --print-build-logs
git commit -am "docs: split, scrub, generated options reference, public API v0.3"
```

---

## Part 8 — Gate nixlab-specific content

**Why.** Three things in the "product" code only make sense on your fleet: an NVIDIA log alert that is always on, six ZFS alerts that need metrics only your NAS scripts produce, and a dashboard panel with your five timer names baked in. Each becomes opt-in or configurable, and a nixlab adapter line (Part 10) switches it back on for you, so nothing changes on your hosts.

**State you start from.** Parts 1–7 are done and committed; `nix flake check` is green; you are in `$OBS` on branch `evolve`. **Names and paths in this part are the new ones**: options are `services.observability…`, and module files live in `modules/nixos/<service>/` (flattened in §5.6). The options added here are new in 0.3, so they have **no old spelling and no compat alias**; nixlab sets them by their new names even in Stage A.

**How the steps are written.** Each edit gives the file, then **Find** (text copied from the file as it is now, which must match exactly once) and **Replace with**. Indentation does not have to match (`nix fmt -- .` fixes it), but the words and punctuation do. If a **Find** block is not in the file, stop and send me that file.

### 8.1 The NVIDIA Xid alert becomes opt-in

**Step 1: add the option.**

> 📝 **Edit `stacks/observability.nix`** · repo `$OBS` · **replace 5 lines**
> **Where:** inside `options.services.observability = { … };`. Search the file for `integrations = {`; it appears once, directly above the line `traefik = mkIntegration`.

**Find:**
```nix
      integrations = {
        traefik = mkIntegration "127.0.0.1:8082" "traefik";
        cadvisor = mkIntegration "127.0.0.1:8080" "cAdvisor container metrics";
        postgres = mkIntegration "127.0.0.1:9187" "the PostgreSQL exporter";
      };
```
**Replace with:**
```nix
      integrations = {
        traefik = mkIntegration "127.0.0.1:8082" "traefik";
        cadvisor = mkIntegration "127.0.0.1:8080" "cAdvisor container metrics";
        postgres = mkIntegration "127.0.0.1:9187" "the PostgreSQL exporter";
        nvidia.enable = lib.mkEnableOption "the NVIDIA Xid log alert (needs the NVIDIA kernel driver)";
      };
```

**Step 2: make the rule conditional.** Two small edits in the same file. Search for `services.observability-loki.ruler = {`; its `groups` list holds one group (`name = "journal"`) whose `rules = [ … ];` holds four rules in this order: `JournalOOMKill`, `KernelFilesystemError`, `NvidiaXid`, `SSHAuthFailureBurst`. The order must not change. The rule bodies are not touched.

> 📝 **Edit `stacks/observability.nix`** · repo `$OBS` · **edit 1 of 2: replace 4 lines**
> **Where:** the boundary between the `KernelFilesystemError` rule and the `NvidiaXid` rule.

**Find:**
```nix
                annotations.summary = "Kernel filesystem or I/O error on {{ $labels.host }}";
              }
              {
                alert = "NvidiaXid";
```
**Replace with:**
```nix
                annotations.summary = "Kernel filesystem or I/O error on {{ $labels.host }}";
              }
            ]
            ++ lib.optional cfg.integrations.nvidia.enable {
                alert = "NvidiaXid";
```

> 📝 **Edit `stacks/observability.nix`** · repo `$OBS` · **edit 2 of 2: replace 4 lines**
> **Where:** the boundary between the `NvidiaXid` rule and the `SSHAuthFailureBurst` rule.

**Find:**
```nix
                annotations.summary = "NVIDIA Xid fault on {{ $labels.host }}";
              }
              {
                alert = "SSHAuthFailureBurst";
```
**Replace with:**
```nix
                annotations.summary = "NVIDIA Xid fault on {{ $labels.host }}";
              }
            ++ [
              {
                alert = "SSHAuthFailureBurst";
```
When both edits are in, the structure is `rules = [ OOM Kernel ] ++ lib.optional cfg.integrations.nvidia.enable { Nvidia } ++ [ { SSH } ];`. The closing `];` of the original `rules = [` now closes the last `++ [`, and needs no change. Run `nix fmt -- .`.

**Step 3: the test.**

> 📝 **Edit `flake/ci/observability-checks.nix`** · repo `$OBS` · **add one check**
> **Where:** the **checks landing spot (D)**, §2.0: directly under the `// {` line inside `checks = …`.
```nix
        nvidia-gated = let
          on = harness.mkTestHost {modules = [harness.minimalStack {services.observability.integrations.nvidia.enable = true;}];};
          rules = h: builtins.toJSON h.config.services.observability-loki.ruler.groups;
        in
          assert !(lib.hasInfix "NvidiaXid" (rules hosts.minimal));
          assert lib.hasInfix "NvidiaXid" (rules on);
            pkgs.runCommand "nvidia-gated" {} "touch $out";
```

**Step 4: check.**
```bash
# run in: $OBS
nix fmt -- . && git add -A
nix build .#checks.x86_64-linux.nvidia-gated --no-link --print-build-logs      # builds with no output
nix flake check --print-build-logs                                              # green
```
**If `nvidia-gated` fails with `assertion … failed`:** the first assertion failing means the rule is still unconditional (edit 1 or 2 is missing); the second failing means the option exists but is not wired (check that `cfg.integrations.nvidia.enable` in the `lib.optional` line is spelled exactly like that). **If the build says `syntax error`:** the two edits are not both in; compare with the structure described above.

**Commit and compare.**
```bash
# run in: $OBS
git commit -m "feat(stack): NVIDIA Xid alert is opt-in (nixlab adapter keeps it on)"
fp $BASELINE/obs-fp-8a
for f in loki-ruler; do echo "== $f"; diff <(jq -r '.. | objects | .alert? // empty' $BASELINE/obs-fp-0/$f.json | sort) <(jq -r '.. | objects | .alert? // empty' $BASELINE/obs-fp-8a/$f.json | sort); done
```
**Expected output:** exactly `< NvidiaXid` under `== loki-ruler`, and nothing else. It means the harness host (which does not opt in) lost the rule. Any other difference is a mistake in the two edits.

### 8.2 The six ZFS alerts become opt-in

These alerts query metrics that only your NAS scripts write: `ZpoolDeviceErrors`, `ZpoolDataErrors`, `ZpoolScrubOverdue`, `ZpoolScrubErrors`, `ZpoolMemberMissing`, `ZpoolMemberReonlined`. The two generic ones, `ZpoolNotOnline` and `ZpoolLowFree`, use node_exporter's own ZFS collector and are not touched.

**Step 1: add the option.**

> 📝 **Edit `modules/nixos/prometheus/_internals/options.nix`** · repo `$OBS` · **replace 2 lines**
> **Where:** inside `maintenance = { … alerts.features = { … }; … }`. Search for `Load PostgresReplicationLag`; the option it belongs to is the last one in `features`.

**Find:**
```nix
          description = "Load PostgresReplicationLag. Requires a postgres exporter (pg_replication_lag_seconds).";
        };
```
**Replace with:**
```nix
          description = "Load PostgresReplicationLag. Requires a postgres exporter (pg_replication_lag_seconds).";
        };
        zfsMembers = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Load the ZFS member and scrub alerts (ZpoolDeviceErrors, ZpoolDataErrors, ZpoolScrubOverdue, ZpoolScrubErrors, ZpoolMemberMissing, ZpoolMemberReonlined). Requires textfile metrics that node_exporter does not produce; see docs/operations/zfs-metrics.md.";
        };
```
Nothing else is needed for the option to reach the rules: `prometheus/_internals/rendered.nix` already passes `cfg.maintenance.alerts.features` on as the alert features.

**Step 2: gate the six rules.** One command adds the line `requires = "zfsMembers";` directly under each of the six `alert = "…";` lines (the same pattern the backup alerts use with `requires = "backup";`):
```bash
# run in: $OBS
f=modules/nixos/prometheus/_internals/maintenance-alerts.nix
for a in ZpoolDeviceErrors ZpoolDataErrors ZpoolScrubOverdue ZpoolScrubErrors ZpoolMemberMissing ZpoolMemberReonlined; do
  A="$a" perl -0pi -e 's/(alert = "\Q$ENV{A}\E";\n)([ \t]+)(expr = )/$1$2requires = "zfsMembers";\n$2$3/' "$f"
done
grep -c 'requires = "zfsMembers"' "$f"        # must print 6
git diff --stat -- "$f"                        # 6 insertions, 0 deletions
```
**What each rule looks like afterwards** (shown for the first one; the other five are the same shape):
```nix
          {
            alert = "ZpoolDeviceErrors";
            requires = "zfsMembers";
            expr = "zfs_vdev_errors > 0";
```
If `grep -c` prints less than 6, a rule has its keys in a different order in your file. Open the file, search for the missing `alert = "<Name>";`, and add the `requires = "zfsMembers";` line by hand directly under it.

**Step 3: tell the CI "all features" set about it.**

> 📝 **Edit `flake/ci/observability-checks.nix`** · repo `$OBS` · **replace 2 lines**
> **Where:** the `allFeatures = { … };` binding in the top `let`.

**Find:**
```nix
      alertmanagerWired = true;
    };
```
**Replace with:**
```nix
      alertmanagerWired = true;
      zfsMembers = true;
    };
```
(`allFeatures` is what `prom-rules-all-features`, `runbook-coverage` and the rule tests use; without this line they would stop seeing the six rules.)

**Step 4: add the metrics document.**
```bash
# run in: $OBS
mkdir -p docs/operations
cp /path/to/zfs-metrics.md docs/operations/zfs-metrics.md     # the file supplied with this guide
```

**Step 5: check, commit, compare.**
```bash
# run in: $OBS
nix fmt -- . && git add -A
nix build .#checks.x86_64-linux.prom-rules-all-features .#checks.x86_64-linux.runbook-coverage .#checks.x86_64-linux.prom-rule-tests --no-link --print-build-logs
nix flake check --print-build-logs
git commit -m "feat(prometheus): ZFS member and scrub alerts are opt-in (zfsMembers)"
fp $BASELINE/obs-fp-8b
for f in loki-ruler prometheus; do echo "== $f"; diff <(jq -r '.. | objects | .alert? // empty' $BASELINE/obs-fp-0/$f.json | sort) <(jq -r '.. | objects | .alert? // empty' $BASELINE/obs-fp-8b/$f.json | sort); done
```
**Expected output:** under `== loki-ruler`, `< NvidiaXid`; under `== prometheus`, exactly these six lines and nothing else: `< ZpoolDataErrors`, `< ZpoolDeviceErrors`, `< ZpoolMemberMissing`, `< ZpoolMemberReonlined`, `< ZpoolScrubErrors`, `< ZpoolScrubOverdue`.
**If `runbook-coverage` fails:** `allFeatures` does not contain `zfsMembers = true;` (Step 3).

### 8.3 The dashboard's timers panel stops naming your timers

The panel "Time since each timer last fired" in `system-overview-v5.json` filters on your five timer names. It will filter on a dashboard variable instead, set from a new Grafana option.

**Step 1: three edits to the dashboard JSON, with one script.** JSON is whitespace-tolerant, so the script matches by content and checks that the result is valid JSON.

> 📝 **Edit `modules/nixos/grafana/dashboards/system-overview-v5.json`** · repo `$OBS` · **three changes**
> **What changes:** (1) a new hidden variable `timers_regex` is added after the existing `prometheus_url` variable in `templating.list`; (2) the `expr` of panel id 412 uses `${timers_regex}`; (3) that panel's `description` stops listing your timers.
```bash
# run in: $OBS
python3 - <<'EOF'
import json, re
p = "modules/nixos/grafana/dashboards/system-overview-v5.json"
s = open(p, encoding="utf-8").read()

# (1) add the variable right after the prometheus_url object
m = re.search(r'"name":\s*"prometheus_url".*?"current":\s*\{.*?\}\s*\}', s, re.S)
assert m, "prometheus_url variable not found"
new_var = ''',
        {
          "name": "timers_regex",
          "label": "Timers",
          "type": "constant",
          "query": "nixos-upgrade.timer|nix-gc.timer",
          "hide": 2,
          "current": {
            "text": "nixos-upgrade.timer|nix-gc.timer",
            "value": "nixos-upgrade.timer|nix-gc.timer"
          }
        }'''
s = s[:m.end()] + new_var + s[m.end():]

# (2) the panel expression
old_expr = '"expr": "time() - node_systemd_timer_last_trigger_seconds{name=~\\"nixos-upgrade.timer|flake-update.timer|backup-home.timer|nixlab-gpull.timer|nix-gc.timer\\"}"'
new_expr = '"expr": "time() - node_systemd_timer_last_trigger_seconds{name=~\\"${timers_regex}\\"}"'
assert s.count(old_expr) == 1, "timer expr not found exactly once"
s = s.replace(old_expr, new_expr)

# (3) the panel description
old_desc = '"description": "How long since each listed systemd timer (nixos-upgrade, flake-update, backup-home, nixlab-gpull, nix-gc) last triggered. A value far beyond the timer\'s schedule means it is stuck, disabled or failing to run."'
new_desc = '"description": "How long since each systemd timer matching the dashboard variable timers_regex last triggered. A value far beyond the timer\'s schedule means it is stuck, disabled or failing to run."'
assert s.count(old_desc) == 1, "timer description not found exactly once"
s = s.replace(old_desc, new_desc)

json.loads(s)                     # must still be valid JSON
open(p, "w", encoding="utf-8").write(s)
print("ok")
EOF
git diff --stat -- modules/nixos/grafana/dashboards/system-overview-v5.json     # about 15 insertions, 2 deletions
```
**Expected output:** `ok`. An `AssertionError` names which of the three pieces was not found: send me that panel's JSON (search the file for `"id": 412`).

**Step 2: two edits to the Grafana module.**

> 📝 **Edit `modules/nixos/grafana/default.nix`** · repo `$OBS` · **edit 1 of 2: add one option**
> **Where:** inside `options.services.observability-grafana = { … };`, directly after the `prometheusUrl` option. Search for `prometheusUrl = lib.mkOption`.

**Find:**
```nix
        prometheusUrl = lib.mkOption {
          type = lib.types.str;
          default = "http://localhost:9090";
          description = "Prometheus URL written into the dashboards' prometheus_url variable (used by the Open in Prometheus links). Must be reachable from the browser.";
        };
```
**Replace with:**
```nix
        prometheusUrl = lib.mkOption {
          type = lib.types.str;
          default = "http://localhost:9090";
          description = "Prometheus URL written into the dashboards' prometheus_url variable (used by the Open in Prometheus links). Must be reachable from the browser.";
        };

        timersRegex = lib.mkOption {
          type = lib.types.str;
          default = "nixos-upgrade.timer|nix-gc.timer";
          example = "nixos-upgrade.timer|backup.timer";
          description = "Regular expression of systemd timer names shown in the system-overview dashboard's \"Time since each timer last fired\" panel (written into the dashboard's timers_regex variable).";
        };
```

> 📝 **Edit `modules/nixos/grafana/default.nix`** · repo `$OBS` · **edit 2 of 2: replace 2 lines**
> **Where:** in the shell script that provisions dashboards (`grafana-provision`, inside the `ExecStartPre` list). Search for `select(.name=="prometheus_url")`; the `jq` command is two lines.

**Find:**
```nix
                        ${pkgs.jq}/bin/jq --arg u "${cfg.prometheusUrl}" \
                          '(.templating.list[]? | select(.name=="prometheus_url")) |= (.query=$u | .current={text:$u,value:$u})' \
```
**Replace with:**
```nix
                        ${pkgs.jq}/bin/jq --arg u "${cfg.prometheusUrl}" --arg t "${cfg.timersRegex}" \
                          '(.templating.list[]? | select(.name=="prometheus_url")) |= (.query=$u | .current={text:$u,value:$u})
                           | (.templating.list[]? | select(.name=="timers_regex")) |= (.query=$t | .current={text:$t,value:$t})' \
```
The next line of the file (`${dashboard.path} > ${cfg.dataDir}/dashboards/${name}/dashboard.json.tmp`) stays as it is. The `zfs-monitoring` dashboard has no `timers_regex` variable; for it the second `select` matches nothing and changes nothing, exactly as the first does today.

**Step 3: check and commit.**
```bash
# run in: $OBS
nix fmt -- . && git add -A
nix build .#checks.x86_64-linux.dashboard-lint .#checks.x86_64-linux.toplevel-stable --no-link --print-build-logs
nix flake check --print-build-logs
git commit -m "feat(grafana): timers panel filters on timersRegex"
```
`dashboard-lint` proves the JSON is still valid with a unique uid; `toplevel-stable` proves the module (and the generated provisioning script) still builds. The fingerprint does not capture dashboard text, so no fingerprint comparison is needed for this step. On a real host after Part 10, you will confirm the variable landed: `jq '.templating.list[] | select(.name=="timers_regex") | .query' /data/grafana/dashboards/system-overview-v5/dashboard.json`.

### 8.4 Remaining nixlab wording

Your code still has the `10.0.0.x` addresses in option examples (one is your `nixnas1`), "nixlab" in an option description, and one script header. Fix all of them with these commands, then confirm nothing is left:
```bash
# run in: $OBS
sed -i 's#http://10\.0\.0\.251:9093/#http://192.0.2.10:9093/#' modules/nixos/alertmanager/default.nix
sed -i 's#http://10\.0\.0\.10:#http://192.0.2.10:#' modules/nixos/grafana/default.nix modules/nixos/ntfy/default.nix modules/nixos/prometheus/_internals/options.nix
sed -i 's#mkEnableOption "nixlab observability stack#mkEnableOption "observability stack#' stacks/observability.nix
sed -i 's#for the nixlab observability stack#for the observability stack#' bin/mon-check.sh
grep -rnE '10\.0\.0\.|nixlab' modules stacks bin sops | grep -v 'nixlab-gpull'
```
**Expected output of the last command:** nothing, or only lines you decide are history (for example a comment about where the code started). Reword anything else by hand. `192.0.2.0/24` is the range reserved for examples.
```bash
# run in: $OBS
nix fmt -- . && git add -A && nix flake check --print-build-logs && git commit -m "docs: neutral examples and wording"
```

---

## Part 9 — CI and release automation

**What you will have at the end:** every push and pull request to the observability repo runs `nix flake check`, the VM smoke test and the example build on GitHub; pushing a tag `vX.Y.Z` creates a GitHub release from `CHANGELOG.md`; a weekly pull request updates `flake.lock`. Everything in this part is in repo `$OBS`; nothing changes on your hosts.

You need: the repo on GitHub as `Temhr/observability`, push rights, and (optional but used below) the GitHub CLI `gh`, logged in (`gh auth status`).

### 9.1 Create the three workflow files

> 📝 **Edit `.github/workflows/ci.yml`** · repo `$OBS` · **create a new file** (and the directories `.github/workflows/`)
> **Where:** new file; paste the whole block. The three `<SHA_…>` words are placeholders that §9.2 fills in.
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
      - uses: actions/checkout@<SHA_CHECKOUT>
      - uses: cachix/install-nix-action@<SHA_INSTALL_NIX>
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

> 📝 **Edit `.github/workflows/release.yml`** · repo `$OBS` · **create a new file**
> **Where:** new file; paste the whole block. A tag `v…-rcN` makes a pre-release with a one-line note; a final tag requires a `## <version>` section in `CHANGELOG.md` and fails without one.
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
      - uses: actions/checkout@<SHA_CHECKOUT>
      - uses: cachix/install-nix-action@<SHA_INSTALL_NIX>
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

> 📝 **Edit `.github/workflows/update-flake-lock.yml`** · repo `$OBS` · **create a new file**
> **Where:** new file; paste the whole block.
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
      - uses: actions/checkout@<SHA_CHECKOUT>
      - uses: cachix/install-nix-action@<SHA_INSTALL_NIX>
      - uses: DeterminateSystems/update-flake-lock@<SHA_UPDATE_LOCK>
        with:
          token: ${{ secrets.FLAKE_UPDATE_TOKEN }}
```

### 9.2 Replace the placeholders with pinned commit SHAs

A SHA is immutable; a tag can be moved. This resolves the current release of each action to its commit SHA.
```bash
# run in: $OBS
resolve() {
  repo=$1
  tag=$(gh api "repos/$repo/releases/latest" --jq .tag_name)
  sha=$(git ls-remote "https://github.com/$repo" "refs/tags/$tag^{}" | cut -f1)
  [ -n "$sha" ] || sha=$(git ls-remote "https://github.com/$repo" "refs/tags/$tag" | cut -f1)
  echo "$repo $tag $sha"
}
resolve actions/checkout
resolve cachix/install-nix-action
resolve DeterminateSystems/update-flake-lock
```
Each line prints `<repo> <tag> <40-character sha>`. Put the three SHAs in variables and substitute them:
```bash
# run in: $OBS
SHA_CHECKOUT=<paste the sha from the actions/checkout line>
SHA_INSTALL_NIX=<paste the sha from the cachix/install-nix-action line>
SHA_UPDATE_LOCK=<paste the sha from the DeterminateSystems/update-flake-lock line>
sed -i "s/<SHA_CHECKOUT>/$SHA_CHECKOUT/g; s/<SHA_INSTALL_NIX>/$SHA_INSTALL_NIX/g; s/<SHA_UPDATE_LOCK>/$SHA_UPDATE_LOCK/g" .github/workflows/*.yml
grep -n 'uses:' .github/workflows/*.yml
```
**Expected output of the last command:** every `uses:` line ends with a 40-character hex string, and **no** `<SHA_` remains. (Without `gh`, open each action's repository on GitHub, click its latest release, and copy the commit SHA shown there.)

### 9.3 Create the token the weekly lock update needs

Pull requests created with the default `GITHUB_TOKEN` do **not** trigger other workflows, so the lock-update PR would never run CI. It needs a personal access token.

1. GitHub → your avatar → **Settings** → **Developer settings** → **Personal access tokens** → **Fine-grained tokens** → **Generate new token**.
2. Name `observability-flake-update`; **Repository access**: only `Temhr/observability`; **Permissions → Repository**: *Contents: Read and write* and *Pull requests: Read and write*. Generate and copy the token.
3. Store it as a repository secret named exactly `FLAKE_UPDATE_TOKEN`:
```bash
# run in: $OBS
gh secret set FLAKE_UPDATE_TOKEN        # paste the token when asked
gh secret list                          # FLAKE_UPDATE_TOKEN is listed
```

### 9.4 Protect `main`

GitHub → the repository → **Settings** → **Branches** → **Add branch protection rule** (or **Rulesets**): branch name pattern `main`; tick **Require a pull request before merging** and **Require status checks to pass before merging**; in the status-check search box choose **`check`** (it appears only after the first run in §9.5; come back and add it then).

### 9.5 Push and prove it works

```bash
# run in: $OBS
nix fmt -- . && git add -A
git commit -m "ci: checks, vm smoke, release and lock-update workflows"
git push -u origin evolve
gh pr create --base main --head evolve --title "0.3.0" --body "Evolution: names, layout, tests, docs."
gh run watch                            # pick the "ci" run; it ends green
```
**Expected:** the `check` job is green, including the `nix build .#vm-smoke` step.
- **`vm-smoke` cannot open `/dev/kvm`:** the "Enable KVM" step must run before the Nix steps (it does, in the file above); look for the `/dev/kvm` lines in that step's log.
- **The runner runs out of disk:** add a step before the Nix steps that frees space, for example `- run: sudo rm -rf /usr/share/dotnet /opt/ghc /usr/local/lib/android`.
- **`nix flake check` fails on GitHub but passes locally:** a file is not committed (`git status`), or a check depends on your machine; the log names it.

Now go back to §9.4 and add **`check`** as the required status check.

---

## Part 10 — Release v0.3.0 and move nixlab over

**The order, in one picture.**

| Step | What | Repo | Hosts affected |
|---|---|---|---|
| 10.1 | release candidate `v0.3.0-rc1` | `$OBS` | none |
| 10.2 | **Stage A**: nixlab pins the rc, adds three adapter lines, proves parity | `$NIXLAB` | none yet |
| 10.3 | canary on `nixvat`, then `nixnas2`, then `nixnas1`, each protected from your timers | `$NIXLAB` | one host at a time |
| 10.4 | tag `v0.3.0`, move nixlab to it, remove the pins, merge | both | **the whole fleet overnight** |
| 10.5 | **Stage B**: nixlab switches to the new names; parity by identical store paths | `$NIXLAB` | whole fleet overnight again |

### 10.0 What your automation does to this (read first)

I read the three modules in `hosts/common/automation/`. Every host runs all three:

| Module | What it does | Consequence for you |
|---|---|---|
| `flake-update` (23:40 + up to 1 h) | in `~/nixlab`: `git pull --rebase`, **`nix flake update` (all inputs)**, commit `flake.lock`, `git push` | A feature branch checked out there gets a lock-wide update commit and a push attempt. A tag in `flake.nix` survives it; a lock edited with `--override-input` does **not**. So always edit the `url` in `flake.nix`. |
| `nixlab-gpull` (hourly) | `git pull --rebase` in `~/nixlab` | It rebases whatever branch is checked out there. |
| `nixos-upgrade` (02:00 ± 30 min) | builds **`github:Temhr/nixlab`** (`main`) with `--no-write-lock-file`, `operation = "boot"`, **`allowReboot = true`** | Merging to `main` rolls the change to **every host that night, with a reboot**. And a canary activated from a branch is **replaced by `main` at 02:00**. |

**So a canary host needs three things:** a separate checkout (never `~/nixlab`), the branch's own configuration deployed with `nixos-rebuild switch`, and the three timers switched off *in that configuration* so nothing puts `main` back. The pins below do that.

### 10.1 Release candidate

```bash
# run in: $OBS
git switch evolve && git status                 # "nothing to commit, working tree clean"
nix flake check --print-build-logs
nix build .#vm-smoke --print-build-logs
git push origin evolve
git tag v0.3.0-rc1 && git push origin v0.3.0-rc1
gh run list --limit 3                            # the "release" run for the tag finishes green
gh release view v0.3.0-rc1                       # a pre-release exists
```

### 10.2 Stage A: pin the rc, add three adapter lines, prove parity

You are in `$NIXLAB` on branch `obs-evolve` (created in §1.3). Nothing here touches a host.

**Step 1: point `flake.nix` at the rc.**

> 📝 **Edit `flake.nix`** · repo `$NIXLAB` · **change one line**
> **Where:** inside `inputs.observability = { url = "…"; … };`, the `url` line. It currently ends in the version you pinned in §1.2 (`/v0.2.1"`).

**Find:**
```nix
      url = "github:Temhr/observability/v0.2.1";
```
**Replace with:**
```nix
      url = "github:Temhr/observability/v0.3.0-rc1";
```
Then update the lock. **Do not use `--override-input`** (§10.0):
```bash
# run in: $NIXLAB
nix flake update observability
git diff --stat flake.lock                       # only the observability entry (and its sub-inputs) changed
```

**Step 2: replace the adapter.** This is the complete Stage A adapter: the v0.2 adapter from §1.2 (old option names, which work through the compat aliases) plus **three lines at the end using the new names**, because those three options are new in 0.3 and have no old spelling.

> 📝 **Edit `stacks/observability-nixlab.nix`** · repo `$NIXLAB` · **replace the whole file**
> **Where:** delete everything in the file and paste this.
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

    # Old option names: they still work in 0.3 through compat aliases (Stage B renames them).
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

    # New in 0.3: these options have no old spelling, so they use their new names even in Stage A.
    # They keep behaviour nixlab relied on before the extraction (Part 8).
    services.observability.integrations.nvidia.enable = lib.mkDefault true;
    services.observability-prometheus.maintenance.alerts.features.zfsMembers = lib.mkDefault true;
    services.observability-grafana.timersRegex = lib.mkDefault "nixos-upgrade.timer|flake-update.timer|backup-home.timer|nixlab-gpull.timer|nix-gc.timer";
  };
}
```

**Step 3: build every host and compare with the baseline.** Takes a while.
```bash
# run in: $NIXLAB
nix fmt -- . && git add -A
nix flake check
for h in nixnas1 nixnas2 nixace nixsun nixtop nixvat nixzen; do
  nix build ".#nixosConfigurations.$h.config.system.build.toplevel" --no-link || echo "FAILED: $h"
done
git commit -m "chore(observability): adopt v0.3.0-rc1 via compat aliases (stage A)"
$BASELINE/capture2.sh $BASELINE/after3           # needs the clean, committed tree; do NOT run `git pull` until Stage B is measured
for h in nixnas1 nixnas2 nixace nixsun nixtop nixvat nixzen; do nix eval --raw ".#nixosConfigurations.$h.config.system.build.toplevel.outPath"; echo; done > $BASELINE/outpaths-A.txt
diff -ru $BASELINE/before3 $BASELINE/after3 -x toplevel > $BASELINE/parity3.diff; wc -l $BASELINE/parity3.diff
```
**Read `parity3.diff`.** Differences that are expected, and everything else is a bug:

| File | Expected? | Meaning |
|---|---|---|
| any `units*.json`: store-path hashes | yes | normalise with `sed -E 's#/nix/store/[a-z0-9]{32}-#/nix/store/#g'` |
| `assertion-count.json` | only if you added assertions | |
| `groups.json`, `users.json` (`extraGroups`), `sops-secrets.json` (`restartUnits`) | order only | the sets must be equal |
| `loki-ruler.json` | **no** | a missing `NvidiaXid` means the `services.observability.integrations.nvidia.enable` line is missing |
| `prometheus-rendered.json` | **no** | six missing `Zpool…` rules mean the `zfsMembers` line is missing |
| `alertmanager.json`, `datasources.json`, `alloy-extra.json`, `firewall-*.json`, `tmpfiles.json` | **no** | any difference is a bug in Parts 3–8 |

Also expected: the rebuild prints **deprecation warnings** ("option … has been renamed") for each old name the adapter still uses. That is the reason for Stage B.
- **`… defined multiple times` on an option the adapter sets with `mkDefault`:** the alias lost the priority; in `$OBS` change `lib.mkRenamedOptionModule` to `lib.mkRenamedOptionModuleWith { from = a.old; to = a.new; sinceRelease = 2505; }` in `compat/options.nix` (two places, `mkAliases`), re-tag the rc.
- **`The option … does not exist`:** send me the full option name.

Write the explanation of every difference to `docs/development/migration/parity-report-3.md` in `$OBS` (headings: *Compared*, *Differences and why*, *Conclusion*), commit it there.

### 10.3 Canary and staged rollout

**Step 1: add the pins to the canary host's file, on the branch.**

> 📝 **Edit `hosts/nixvat.nix`** · repo `$NIXLAB` · **edit 1 of 2: add one argument**
> **Where:** the argument list of the `hosts--nixvat` module (the `{ config, inputs, pkgs, … }: {` after `flake.nixosModules.hosts--nixvat =`).

**Find:**
```nix
      config,
      inputs,
      pkgs,
      ...
    }: {
      imports = [
        "${inputs.nixpkgs}/nixos/modules/profiles/qemu-guest.nix"
```
**Replace with:**
```nix
      config,
      inputs,
      lib,
      pkgs,
      ...
    }: {
      imports = [
        "${inputs.nixpkgs}/nixos/modules/profiles/qemu-guest.nix"
```

> 📝 **Edit `hosts/nixvat.nix`** · repo `$NIXLAB` · **edit 2 of 2: add the pins**
> **Where:** at the end of the same module, directly above the `system.stateVersion` line (its comment line starts `# https://nixos.wiki/wiki/FAQ`).

**Find:**
```nix
      # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
      system.stateVersion = "24.11";
```
**Replace with:**
```nix
      # CANARY PINS: remove in the commit before the merge to main (§10.4).
      system.autoUpgrade.enable = lib.mkForce false; # else the 02:00 upgrade puts main back
      systemd.timers.flake-update.enable = lib.mkForce false; # else it runs `nix flake update` here
      systemd.timers.nixlab-gpull.enable = lib.mkForce false;

      # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
      system.stateVersion = "24.11";
```
Commit and push it from your working machine:
```bash
# run in: $NIXLAB
nix fmt -- . && git add -A && nix build ".#nixosConfigurations.nixvat.config.system.build.toplevel" --no-link
git commit -m "chore(canary): pin nixvat to the branch (remove before merge)"
git push -u origin obs-evolve
```

**Step 2: deploy it on `nixvat` from a separate checkout.**
```bash
# run in: nixvat, as your user (NOT in ~/nixlab)
git clone git@github.com:Temhr/nixlab.git ~/nixlab-canary
cd ~/nixlab-canary && git switch obs-evolve
sudo nixos-rebuild switch --flake ~/nixlab-canary#nixvat
```

**Step 3: verify on `nixvat`.** Every command should give the stated result.
```bash
# run in: nixvat
systemctl --failed --no-legend | wc -l                                   # 0
for u in prometheus loki alloy grafana alertmanager ntfy; do printf '%s ' $u; systemctl is-active $u; done   # six lines, all "active"
id temhr | tr ',' '\n' | grep -cE 'loki|prometheus|grafana|ntfy|alloy'  # 5
nix run github:Temhr/observability/v0.3.0-rc1#mon-check                  # all OK lines
nix run github:Temhr/observability/v0.3.0-rc1#mon-check -- --fire-test  # "alert reached ntfy after about N s"
sudo grep -c NvidiaXid /data/loki/rules/fake/journal.yaml                # 1  (the adapter line works)
sudo grep -c ZpoolDeviceErrors /data/prometheus/rules/alerts.yml         # 1  (the zfsMembers line works)
jq '.templating.list[] | select(.name=="timers_regex") | .query' /data/grafana/dashboards/system-overview-v5/dashboard.json
                                                                         # "nixos-upgrade.timer|flake-update.timer|backup-home.timer|nixlab-gpull.timer|nix-gc.timer"
sudo systemctl start observability-backup && sudo ls -la /data/backup    # *.bak files, recent
```
Then `sudo reboot`, wait, and run the first three commands again. **Soak at least 3 days** (a nightly backup run and some real alert traffic). Confirm the pins hold: after 02:30, `systemctl list-timers | grep -E 'nixos-upgrade|flake-update|nixlab-gpull'` prints nothing, and `nixos-rebuild list-generations | head -n 3` still shows the generation you deployed.

**Step 4: repeat for the next hosts, one at a time:** `nixnas2` (the other nixpkgs channel), then `nixnas1` (your ZFS host; this is where the `zfsMembers` alerts and the ZFS metrics matter, so also run `curl -s localhost:9100/metrics | grep -c '^zfs_'` and confirm the six names from `docs/operations/zfs-metrics.md` appear). For each, add the same three pin lines to `hosts/<host>.nix` (add `lib` to the module's arguments; put the pin block directly above that file's `system.stateVersion` line), commit, push, and deploy from `~/nixlab-canary` with `git pull` first. If a host file's shape differs from `nixvat.nix`, send me the file.

### 10.4 Release v0.3.0, remove the pins, merge

Only when the three hosts have soaked.

**Step 1: tag the final release.**
```bash
# run in: $OBS
git switch evolve && git status                          # clean
# make sure CHANGELOG.md has a "## 0.3.0" section at the top (§7.6)
git push origin evolve
gh pr merge --merge --delete-branch=false                # or merge the PR in the GitHub UI
git switch main && git pull
git tag -a v0.3.0 -m "Product-scoped names with compat aliases, flat layout, one owner per setting, vm test, generated docs"
git push origin main v0.3.0
gh release view v0.3.0                                   # the release exists, with your changelog text
```

**Step 2: in nixlab, remove the pins and move to the final tag.** Everything here is on branch `obs-evolve`.
```bash
# run in: $NIXLAB
git switch obs-evolve
sed -i 's#observability/v0.3.0-rc1"#observability/v0.3.0"#' flake.nix
nix flake update observability
```
Remove the pins from **every host file that has them** (`hosts/nixvat.nix`, `hosts/nixnas2.nix`, `hosts/nixnas1.nix`): delete the three lines `system.autoUpgrade.enable = lib.mkForce false;`, `systemd.timers.flake-update.enable = lib.mkForce false;`, `systemd.timers.nixlab-gpull.enable = lib.mkForce false;` and the `# CANARY PINS` comment above them. (`lib` in the argument list may stay.)
```bash
# run in: $NIXLAB
grep -rn "CANARY PINS" hosts                              # prints nothing
git add -A && nix flake check
for h in nixnas1 nixnas2 nixace nixsun nixtop nixvat nixzen; do nix build ".#nixosConfigurations.$h.config.system.build.toplevel" --no-link || echo "FAILED: $h"; done
git commit -m "chore(observability): pin v0.3.0; remove canary pins"
```

**Step 3: merge.** This is the step that rolls the fleet.
> Merging to `main` makes **every host** upgrade and **reboot** between 02:00 and 02:30 that night. Do it when that is acceptable.
```bash
# run in: $NIXLAB
git switch main && git pull
git merge --no-ff obs-evolve
git push origin main
```
Next morning, on any host: `nix run github:Temhr/observability/v0.3.0#mon-check` and `systemctl --failed`.

### 10.5 Stage B: switch nixlab to the new names

Wait until the fleet has run v0.3.0 for about a week. Then, **without pulling in between** (a nightly lock update would move nixpkgs and spoil the comparison):

**Step 1: record the "before" store paths from the current `main`.**
```bash
# run in: $NIXLAB
git switch main && git pull
for h in nixnas1 nixnas2 nixace nixsun nixtop nixvat nixzen; do nix eval --raw ".#nixosConfigurations.$h.config.system.build.toplevel.outPath"; echo; done > $BASELINE/outpaths-A2.txt
git switch -c obs-names
```

**Step 2: rename the option names in nixlab's own files.**
```bash
# run in: $NIXLAB
bash $OBS/docs/development/migration/rename-tokens.sh $OBS/docs/development/migration/rename-map.txt hosts home modules stacks flake sops
git diff --stat
```
**Expected files changed:** `hosts/common/profile-base.nix`, `hosts/common/profile-desktop.nix`, `hosts/common/profile-nas.nix`, `hosts/nixnas1.nix` (if it sets observability options) and `stacks/observability-nixlab.nix`. Look at the diff:
```bash
git diff -- hosts
```
You should see only lines like `-services.nixlab-observability = {` → `+services.observability = {`, `-services.prometheus-nixlab.maintenance.expectedMounts` → `+services.observability-prometheus.maintenance.expectedMounts`, `-services.grafana-nixlab.extraDashboards` → `+services.observability-grafana.extraDashboards`. Anything else: stop and send me the diff.

**Step 3: replace the adapter** (the script cannot do this: it must also stop importing through nixlab's own `self.nixosModules.*`).

> 📝 **Edit `stacks/observability-nixlab.nix`** · repo `$NIXLAB` · **replace the whole file**
> **Where:** delete everything in the file and paste this.
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

**Step 4: delete the re-export** (nixlab no longer presents the observability modules as its own).
```bash
# run in: $NIXLAB
git rm flake/observability.nix
git add -A
# Any old name left? Lines naming stack--observability-nixlab (the adapter's own name) are fine.
awk '{print $1}' $OBS/docs/development/migration/rename-map.txt | while read -r t; do git grep -nF -e "$t" -- hosts home modules stacks flake sops; done | grep -v 'stack--observability-nixlab'
```
**Expected output of the last command:** nothing.

**Step 5: prove nothing changed.**
```bash
# run in: $NIXLAB
nix fmt -- . && git add -A && nix flake check
for h in nixnas1 nixnas2 nixace nixsun nixtop nixvat nixzen; do nix eval --raw ".#nixosConfigurations.$h.config.system.build.toplevel.outPath"; echo; done > $BASELINE/outpaths-B.txt
diff $BASELINE/outpaths-A2.txt $BASELINE/outpaths-B.txt && echo "toplevels identical"
```
**Expected:** `toplevels identical`. A pure rename produces identical store paths, which is the strongest parity there is. If they differ, run `$BASELINE/capture2.sh $BASELINE/after-B` (it still works: the old names read through the aliases) and `diff -ru $BASELINE/after3 $BASELINE/after-B -x toplevel`; **only list-order differences** (`extraGroups`, `restartUnits`) are acceptable. Anything else, send me the diff.
The deprecation warnings are gone from `nixos-rebuild build`.

**Step 6: roll out** as in §10.3 (canary pins on one host, soak, then the others), then merge as in §10.4 Step 3.
```bash
# run in: $NIXLAB
git commit -m "refactor(observability): use product-scoped option and module names; drop re-export (stage B)"
```

---

## Part 11 — Policy changes (the only deliberate behaviour changes)

Everything before this part was designed to change nothing your hosts do. These five items change behaviour on purpose, so each is **its own change**: make it, test it, deploy it to one host, soak, then roll it out. Never combine two. Where the change lives is stated at the start of each item (`$NIXLAB` only, or `$OBS` plus a patch release).

**How to deploy any nixlab change from this part safely:** follow §10.3 (separate checkout, the three timer pins in the canary host's file, soak, then remove the pins and merge). It is not repeated below.

### 11.1 Network exposure and Wi-Fi

**Repos:** `$OBS` (one ADR, documentation only, no release) and `$NIXLAB` (one line).

**The facts.** `profile-base` sets `access.expose = ["grafana" "ntfy" "prometheus"]` and `notifications.ntfyAuth.enable = false`. `profile-desktop` passes `[hostMeta.ethIface hostMeta.wifiIface]`. So on `nixace`, `nixsun`, `nixtop`, `nixvat` and `nixzen`, **ntfy (anyone may read and publish alerts) and Prometheus (no authentication) are reachable by anyone on the Wi-Fi network**; only Grafana has a login. `flake/data/hosts-meta.nix` shows every host has an `ethIface`; `nixnas1` has no Wi-Fi and `nixnas2`'s Wi-Fi is already ignored by `profile-nas`. So wired-only works on every host.

| Option | Effect | Cost |
|---|---|---|
| A. Keep, document | Wi-Fi stays open | none |
| **B. Wired only** (recommended) | desktops pass only `ethIface` | a laptop used undocked on Wi-Fi loses LAN access to its dashboards (still reachable on loopback or over an SSH tunnel) |
| C. Authenticate, then keep | turn on ntfy auth fleet-wide, expose only Grafana and ntfy on Wi-Fi | secret setup; more moving parts |

The steps below implement **B**. If you choose A or C, change the *Decision* in the ADR to match and skip the nixlab edit.

**Step 1: record the decision.**

> 📝 **Edit `docs/architecture/decisions/ADR-011-wifi-exposure.md`** · repo `$OBS` · **create a new file**
> **Where:** new file; paste the whole block (replace `<date>`).
````markdown
# ADR-011: Network exposure on wireless interfaces

- **Status:** Accepted (<date>)
- **Related:** ADR-008 (exposure policy), ADR-009 (secrets)

## Context

ADR-008 leaves the choice of interfaces to the consumer. The nixlab consumer passed both its wired and its wireless interface on desktops and laptops. With ntfy authentication off, ntfy (anyone may read and publish alerts) and Prometheus (no authentication at all) were reachable by anyone on the Wi-Fi network; only Grafana has a login. Every nixlab host has a wired interface.

## Decision

1. The consumer exposes the stack on **wired interfaces only**. The nixlab desktop profile passes `ethIface` and no longer passes `wifiIface`.
2. The observability flake stays neutral (ADR-008 stands): it does not know which interface is wireless and does not filter names.
3. The flake's documentation states that Prometheus, Loki and Alertmanager have no authentication and that ntfy is open unless `notifications.ntfyAuth.enable` is set.
4. Exposing on Wi-Fi remains possible by naming that interface explicitly. That is the consumer's decision and should be paired with `notifications.ntfyAuth.enable = true`.

## Alternatives considered

- Keep both interfaces (the previous behaviour): rejected, it exposes unauthenticated services to a shared network.
- Authenticate and keep Wi-Fi: deferred; it needs fleet-wide secret provisioning.
- A per-service interface policy inside the flake: rejected, it adds public surface for a decision that belongs to the consumer.

## Consequences

A laptop used undocked on Wi-Fi loses LAN access to its dashboards (they remain on loopback and reachable over an SSH tunnel).
````

> 📝 **Edit `docs/architecture/decisions/README.md`** · repo `$OBS` · **add two rows**
> **Where:** the table; directly after the ADR-009 row.

**Find:**
```markdown
| [009](ADR-009-secrets.md) | Secrets integration | Accepted |
```
**Replace with:**
```markdown
| [009](ADR-009-secrets.md) | Secrets integration | Accepted |
| [010](ADR-010-final-names.md) | Final module and option names | Accepted |
| [011](ADR-011-wifi-exposure.md) | Network exposure on wireless interfaces | Accepted |
```
(Skip the ADR-010 row if you already added it in Part 5.) Also, in `docs/architecture/decisions/ADR-003-module-namespace.md`:

**Find:**
```markdown
- **Status:** Accepted (2026-11-17)
```
**Replace with:**
```markdown
- **Status:** Accepted; decisions 4 and 5 superseded by ADR-010
```
```bash
# run in: $OBS
git add -A && git commit -m "docs(adr): ADR-011 wired-only exposure; mark ADR-003 decisions 4-5 superseded"
git push
```

**Step 2: record which interfaces are open today.**
```bash
# run in: $NIXLAB
for h in nixace nixsun nixtop nixvat nixzen; do
  echo "$h: $(nix eval --json ".#nixosConfigurations.$h.config.networking.firewall.interfaces" | jq -c 'keys')"
done | tee $BASELINE/firewall-before-11-1.txt
```
**Expected today:** two names per host, for example `nixvat: ["enp0s25","wlo1"]`.

**Step 3: the nixlab edit.**

> 📝 **Edit `hosts/common/profile-desktop.nix`** · repo `$NIXLAB` · **replace one line**
> **Where:** inside the `hosts--profl--desktop` module body. Search for `access.interfaces`.

**Find:**
```nix
    services.observability.access.interfaces = [hostMeta.ethIface hostMeta.wifiIface];
```
**Replace with:**
```nix
    services.observability.access.interfaces = [hostMeta.ethIface];
```
(No `lib` argument is needed: every host has a non-empty `ethIface`.)
```bash
# run in: $NIXLAB
nix fmt -- . && git add -A && nix flake check
for h in nixace nixsun nixtop nixvat nixzen; do
  echo "$h: $(nix eval --json ".#nixosConfigurations.$h.config.networking.firewall.interfaces" | jq -c 'keys')"
done
```
**Expected now:** one name per host: `nixace: ["enp0s31f6"]`, `nixsun: ["enp0s25"]`, `nixtop: ["enp0s25"]`, `nixvat: ["enp0s25"]`, `nixzen: ["enp0s25"]`. The `nixnas*` hosts were already wired-only and are unchanged.
```bash
git commit -m "fix(observability): expose on wired interfaces only (ADR-011)"
```

**Step 4: prove it on the canary** (deploy with §10.3's recipe first). On `nixvat`, note its two addresses:
```bash
# run in: nixvat
ip -br -4 addr                                    # note the address on the wired NIC (enp0s25) and on the Wi-Fi NIC (wlo1)
```
From **another machine on the same network**:
```bash
curl -m 3 -s -o /dev/null -w '%{http_code}\n' http://<nixvat-wired-ip>:3101/api/health   # 200
curl -m 3 -s -o /dev/null -w '%{http_code}\n' http://<nixvat-wifi-ip>:3101/api/health    # 000 (timeout: closed)
```

### 11.2 Narrow the NVIDIA alert to NVIDIA hosts

**Repo:** `$NIXLAB` only.

**Step 1: see which hosts have the NVIDIA driver.**
```bash
# run in: $NIXLAB
for h in nixnas1 nixnas2 nixace nixsun nixtop nixvat nixzen; do
  printf '%s: ' $h; nix eval --json ".#nixosConfigurations.$h.config.services.xserver.videoDrivers"
done
```
**Decide:** the hosts whose list contains `"nvidia"` are the ones that should keep the alert. If a host you know has an NVIDIA GPU does *not* list `"nvidia"` here, stop: the detection below would turn the alert off for it. Send me that host's output.

**Step 2: edit the adapter.**

> 📝 **Edit `stacks/observability-nixlab.nix`** · repo `$NIXLAB` · **replace one line**
> **Where:** inside `services.observability = { … };`.

**Find:**
```nix
      integrations.nvidia.enable = lib.mkDefault true;   # Part 11.2 narrows this
```
**Replace with:**
```nix
      integrations.nvidia.enable = lib.mkDefault (builtins.elem "nvidia" config.services.xserver.videoDrivers);
```
```bash
# run in: $NIXLAB
nix fmt -- . && git add -A && nix flake check
for h in nixnas1 nixnas2 nixace nixsun nixtop nixvat nixzen; do
  printf '%s: ' $h; nix eval --json ".#nixosConfigurations.$h.config.services.observability-loki.ruler.groups" | jq -r '[.. | objects | .alert? // empty] | map(select(. == "NvidiaXid")) | length'
done
```
**Expected:** `1` for each host with the NVIDIA driver and `0` for the others.
```bash
git commit -m "feat(observability): NVIDIA Xid alert only on hosts with the NVIDIA driver"
```
On a host without NVIDIA after deploying: `sudo grep -c NvidiaXid /data/loki/rules/fake/journal.yaml` prints `0`.

### 11.3 Hardening review

**Repos:** `$OBS` (a patch release per accepted change) then `$NIXLAB` (bump the tag).

**Step 1: measure today.** On the canary host:
```bash
# run in: nixvat
nix run github:Temhr/observability/v0.3.0#mon-snapshot -- /tmp/h
cat /tmp/h/security.txt                          # one line per unit: its systemd-analyze security score
systemd-analyze security prometheus.service --no-pager | head -n 40     # the line-by-line detail for one unit
```

**Step 2: record it.**

> 📝 **Edit `docs/security/hardening.md`** · repo `$OBS` · **create a new file** (and the directory `docs/security/`)
> **Where:** new file; paste this, then fill the table from `security.txt`.
````markdown
# Hardening baseline

Scores are `systemd-analyze security` exposure levels (lower is better), measured on <host> on <date>.

| Unit | Score | Exceptions that are deliberate | Reason |
|---|---|---|---|
| prometheus | | | |
| loki | | | |
| alloy | | JIT allowed, /proc fully visible | Alloy needs it |
| grafana | | UMask 0027 | dashboards are group-readable |
| ntfy | | | |
| alertmanager | | (upstream NixOS module) | |
| prometheus-node-exporter | | no syscall filter, ProtectClock off, /proc visible | timex/pressure/hwmon collectors |
| prometheus-smartctl-exporter | | CAP_SYS_RAWIO, PrivateDevices off | reads SMART data |
````

**Step 3: try one change at a time.** The services call `obsLib.mkServiceHardening { writablePaths = …; extraHardening = true; }`; you tighten by adding an argument. Example experiment: ntfy serves only TCP, so Unix sockets are probably unnecessary.

> 📝 **Edit `modules/nixos/ntfy/default.nix`** · repo `$OBS` · **replace 4 lines**
> **Where:** inside `systemd.services.ntfy = { … serviceConfig = … }`. Search for `obsLib.mkServiceHardening`.

**Find:**
```nix
            obsLib.mkServiceHardening {
              writablePaths = [cfg.dataDir];
              extraHardening = true;
            }
```
**Replace with:**
```nix
            obsLib.mkServiceHardening {
              writablePaths = [cfg.dataDir];
              extraHardening = true;
              allowUnixSockets = false;
            }
```
Test it on the canary (deploy per §10.3 with the branch of `$OBS` pinned in nixlab's `flake.nix` for the experiment):
```bash
# run in: nixvat
systemctl is-active ntfy                          # active
journalctl -u ntfy -b --no-pager | grep -iE 'denied|status=31|SYS|Address family' | head      # nothing
nix run github:Temhr/observability/<branch-or-tag>#mon-check -- --fire-test                  # alert reaches ntfy
```
**Accept** the change only if all three pass and `systemd-analyze security ntfy.service` shows a lower score. **Revert** it (delete the added line) if `ntfy` fails, if the journal shows `status=31` (a syscall filter killed it) or `Address family not supported`, or if the alert no longer arrives. Write each result, accepted or not, with the reason, in `docs/security/hardening.md`.

**Step 4: release the accepted changes together as a patch release.**
```bash
# run in: $OBS
# add a "## 0.3.1" section to CHANGELOG.md listing each accepted hardening flag
nix flake check && git commit -am "hardening: <what you accepted>"
git tag v0.3.1 && git push origin main v0.3.1
```
Then in `$NIXLAB`: `sed -i 's#observability/v0.3.0"#observability/v0.3.1"#' flake.nix && nix flake update observability`, and deploy by §10.3.

### 11.4 Backup and restore drill

**Repo:** `$OBS` (documentation); the drill runs on a host.

**What the backup does** (from the module): every night at 03:15 `observability-backup` copies the SQLite databases (`grafana.db`, ntfy's `cache.db` and, when ntfy auth is on, `user.db`) with `sqlite3 .backup` to `<dataDir>/backup/<name>.bak`, and copies Alertmanager's state directory and the maintenance log as they are. The files are mode 0600, root only. **Prometheus data and Loki chunks are not backed up.**

**Step 1: write the procedure down.**

> 📝 **Edit `docs/operations/backup-restore.md`** · repo `$OBS` · **create a new file**
> **Where:** new file; paste the whole block.
````markdown
# Backup and restore

## What is backed up

A nightly job (`observability-backup`, 03:15) writes to `<dataDir>/backup` (default `/data/backup`), mode 0600, root only:

| File | Source |
|---|---|
| `grafana.db.bak` | `<dataDir>/grafana/data/grafana.db` |
| `cache.db.bak` | `<dataDir>/ntfy/cache.db` (if the cache is persistent) |
| `user.db.bak` | `<dataDir>/ntfy/user.db` (if ntfy auth is on) |
| `alertmanager/` | `/var/lib/private/alertmanager` (silences, notification log) |
| `maintenance.jsonl` | `/var/log/maintenance.jsonl` |

Prometheus metrics and Loki logs are **not** backed up. Include `<dataDir>/backup` in your normal off-host backup.

## Check a backup

```bash
sudo systemctl start observability-backup && sudo ls -la /data/backup
sudo sqlite3 /data/backup/grafana.db.bak 'PRAGMA integrity_check;'          # ok
sudo sqlite3 /data/backup/grafana.db.bak 'select count(*) from dashboard;'  # a plausible number
```

## Restore Grafana

```bash
sudo systemctl stop grafana
sudo mv /data/grafana/data/grafana.db /data/grafana/data/grafana.db.keep      # keep the live copy until you are satisfied
sudo cp /data/backup/grafana.db.bak /data/grafana/data/grafana.db
sudo chown grafana:grafana /data/grafana/data/grafana.db
sudo chmod 0640 /data/grafana/data/grafana.db
sudo systemctl start grafana
```
The `chown` is required: `grafana-permissions` is a `RemainAfterExit` unit and does not run again on a plain restart. Verify: sign in, open the dashboards, then `mon-check`.

## Restore ntfy (users and cache)

```bash
sudo systemctl stop ntfy
sudo cp /data/backup/user.db.bak  /data/ntfy/user.db      # only if ntfy auth is on
sudo cp /data/backup/cache.db.bak /data/ntfy/cache.db
sudo chown ntfy:ntfy /data/ntfy/user.db /data/ntfy/cache.db
sudo systemctl start ntfy && sudo systemctl restart ntfy-provision   # ntfy-provision re-creates users from the secrets file if needed
```

## Restore Alertmanager (silences)

```bash
sudo systemctl stop alertmanager
sudo cp -a /var/lib/private/alertmanager /var/lib/private/alertmanager.keep
sudo cp -a /data/backup/alertmanager/. /var/lib/private/alertmanager/
sudo systemctl start alertmanager          # systemd fixes the ownership of its state directory on start
```

## Restore the maintenance log

```bash
sudo cp -a /data/backup/maintenance.jsonl /var/log/maintenance.jsonl
sudo chown root:wheel /var/log/maintenance.jsonl && sudo chmod 0664 /var/log/maintenance.jsonl
```

After any restore, run `mon-check`; keep the `.keep` copies until it passes and you are satisfied, then delete them.
````

**Step 2: do the drill on the canary, then once on a NAS.** Run the "Check a backup" block and the **Grafana restore** block from your document, exactly as written, then `mon-check`. **Pass** means: the integrity check prints `ok`, Grafana comes back with your dashboards, and `mon-check` is all `OK`. If any step needed a command that is not in the document, add it to the document now.
```bash
# run in: $OBS
git add -A && git commit -m "docs: backup and restore procedure, drilled on <host>"
```

### 11.5 Secret rotation

**Repo:** `$OBS` (documentation); rotation itself happens in `$NIXLAB`.

The wiki referenced `docs/secrets-rotation.md` and `bin/rotate-secret.sh`; neither exists. This replaces them.

> 📝 **Edit `docs/operations/secret-rotation.md`** · repo `$OBS` · **create a new file**
> **Where:** new file; paste the whole block.
````markdown
# Secret rotation

The stack uses three secrets. Rotate each as below, then verify.

| Secret | Holds | Consumed by |
|---|---|---|
| Alertmanager environment file (`ALERTMANAGER_ENV`) | `NTFY_ALERTMANAGER_PASSWORD`, `NTFY_READER_PASSWORD`, and any `$VAR` used in receivers (Slack, PagerDuty, SMTP…) | Alertmanager; `ntfy-provision` when ntfy auth is on |
| Grafana admin password (`GRAFANA_ADMIN_PASSWORD`) | the admin password | Grafana, **first start only** |
| Grafana secret key (`GRAFANA_SECRET_KEY`) | the key that encrypts secrets stored in Grafana's database | Grafana |

## Rotate the Alertmanager environment file

1. Edit the secret where you keep it. With sops-nix: `sops <path-to-encrypted-env-file>`, change the value(s), save.
2. Deploy. With the optional `nsops--observability-alertmanager` module a changed secret restarts `alertmanager.service` and, if ntfy auth is on, `ntfy-provision.service`. Without it, restart both yourself.
3. Verify: `mon-check --fire-test` (with ntfy auth on, set `MON_NTFY_AUTH=reader:<new reader password>`). The test alert must reach ntfy.

## Rotate the Grafana admin password

Grafana applies `GRAFANA_ADMIN_PASSWORD` only when it creates a **new** database. On an existing instance, change the secret **and** run:
```bash
sudo -u grafana grafana cli --homepath /var/lib/grafana admin reset-admin-password '<new password>'
```
Adjust `--homepath` to your Grafana package's home path if that command reports it cannot find its configuration; the password must also be changed in the secret file so a rebuilt instance starts with it.

## Rotate the Grafana secret key (rarely; read first)

Changing `GRAFANA_SECRET_KEY` on an existing database makes every secret stored in it (datasource passwords, API keys) unreadable. **Back up first** (see [backup-restore.md](backup-restore.md)), rotate only if the key is compromised, and re-enter the stored secrets afterwards.

## Record it

Log each rotation: `sudo maintenance-log --section IV.11 --task "Rotated <secret>" --status completed`.
````
```bash
# run in: $OBS
git add -A && git commit -m "docs: secret rotation procedure"
```

---

## Part 12 — READMEs and the docs index

You will copy three files that were written for you (the observability README, the nixlab README, and the docs index below), then check the links. Nothing is rewritten by hand.

### 12.1 The observability README

The file supplied as `observability-README.md` replaces the current `README.md`.
```bash
# run in: $OBS
cp /path/to/observability-README.md README.md           # the supplied file
grep -n 'TODO' README.md                                 # one line: the licence placeholder
```
**Fill the licence section:** add a `LICENSE` file to the repository root (choose a licence), then edit the last section of `README.md`.

> 📝 **Edit `README.md`** · repo `$OBS` · **replace one line**
> **Where:** the last section, `## Licence`.

**Find:**
```markdown
TODO: add a `LICENSE` file and name the licence here.
```
**Replace with:** your licence line, for example:
```markdown
MIT, see [`LICENSE`](LICENSE).
```
Also check that the example pins the tag you are about to release: the README says `v0.3.0` in the quick start and in the `nix run` lines; change all of them with `sed -i 's#v0\.3\.0#vX.Y.Z#g' README.md` if you release something else.

### 12.2 The docs index

> 📝 **Edit `docs/README.md`** · repo `$OBS` · **create a new file**
> **Where:** new file; paste the whole block.
````markdown
# Documentation

| I want to… | Read |
|---|---|
| understand how the stack is built | [architecture/overview.md](architecture/overview.md) |
| know what is stable (names, options, state) | [architecture/public-api.md](architecture/public-api.md) |
| see every option with its default | [reference/options.md](reference/options.md) (generated) |
| understand a design decision | [architecture/decisions/](architecture/decisions/) |
| install and configure it | [operations/install-and-configure.md](operations/install-and-configure.md) |
| back up and restore | [operations/backup-restore.md](operations/backup-restore.md) |
| rotate a secret | [operations/secret-rotation.md](operations/secret-rotation.md) |
| set up the ZFS alerts | [operations/zfs-metrics.md](operations/zfs-metrics.md) |
| fix a firing alert | [runbooks/](runbooks/) |
| add a scrape target, alert or dashboard | [development/extending.md](development/extending.md) |
| run or write tests | [development/testing.md](development/testing.md) |
| review hardening | [security/hardening.md](security/hardening.md) |
| see how this repo was extracted from nixlab | [development/migration/](development/migration/) |
````

### 12.3 Check every link

```bash
# run in: $OBS
nix fmt -- . && git add -A
nix build .#checks.x86_64-linux.docs-links --no-link --print-build-logs
```
**Expected:** it builds. If it lists a broken link, the target file does not exist yet: create it (the files named in 12.2 that you have not written, such as `operations/install-and-configure.md`, come from splitting the wiki in §7.2) or correct the link. Then:
```bash
git commit -m "docs: README, docs index"
```

### 12.4 The nixlab README

The file supplied as `README.md` (the nixlab README) replaces nixlab's.
```bash
# run in: $NIXLAB
cp /path/to/README.md README.md                          # the supplied nixlab README
mkdir -p docs/migration
cp /path/to/guide-1-extraction.md docs/migration/obs-01-extraction.md
cp /path/to/guide-2-decoupling.md docs/migration/obs-02-decoupling.md
cp /path/to/guide-3-evolution.md docs/migration/obs-03-evolution.md
```
**One edit to match §11.1 (wired-only):**

> 📝 **Edit `README.md`** · repo `$NIXLAB` · **replace one line**
> **Where:** the profile snippet in the "Observability (external flake)" section. Search for `wifiIface`.

**Find:**
```nix
services.observability.access.interfaces = [ hostMeta.ethIface hostMeta.wifiIface ];   # …and on which interfaces
```
**Replace with:**
```nix
services.observability.access.interfaces = [ hostMeta.ethIface ];                       # …and on which interfaces (wired only, ADR-011)
```
Then check these lines print nothing, and commit:
```bash
grep -n "docs/observability\|mon-check.sh\|stack--observability\b[^-]" README.md
git add -A && git commit -m "docs(readme): observability lives in its own flake"
```

---

## Part 13 — Remove the compatibility layer, then 1.0

### 13.1 v0.4.0: delete the compat layer

**Precondition:** nixlab has run on the new names (Stage B, §10.5) for at least a week, and nothing else you own uses an old name: `git grep -nE 'nixlab-observability|-nixlab\.' ` in every consumer shows only unrelated names.

**Step 1: edits in `$OBS`.**
```bash
# run in: $OBS
git switch main && git pull && git switch -c drop-compat
git rm -r compat
```

> 📝 **Edit `flake.nix`** · repo `$OBS` · **delete one line**
> **Where:** the `imports = [ … ];` list of the `mkFlake` call; search for `compat`.

**Find (delete this line):**
```nix
        (inputs.import-tree ./compat)
```

> 📝 **Edit `stacks/observability.nix`** · repo `$OBS` · **delete one line**
> **Where:** the `imports = [ … ];` list near the top of the module; search for `compat-options`.

**Find (delete this line):**
```nix
      self.nixosModules.compat-options
```

> 📝 **Edit `docs/architecture/public-api.md`** · repo `$OBS` · **delete one section, add one**
> **Where:** delete everything from the heading `## Deprecated names` up to (not including) `## Changes in 0.3`; in its place add the following, and add `## 0.4.0` to the CHANGELOG (next block).
```markdown
## Migrating from 0.2 or 0.3

The `-nixlab` option and module names were removed in 0.4.0. Use the product-scoped names (`services.observability-<component>`, `servc--observability-<component>`, `systm--observability-<component>`, `nsops--observability-<component>`); every option kept its name below the namespace. The full old-to-new tables are in the 0.3.0 section of `CHANGELOG.md` and ADR-010.
```

> 📝 **Edit `CHANGELOG.md`** · repo `$OBS` · **add a section**
> **Where:** at the top, directly under the title line.
```markdown
## 0.4.0
### Removed
- All names deprecated in 0.3.0: the `-nixlab` option namespaces and module names (see ADR-010).
```

**Step 2: check, release, update nixlab.**
```bash
# run in: $OBS
nix fmt -- . && git add -A
git grep -n 'compat' -- . ':!docs/development' ':!CHANGELOG.md' ':!docs/architecture/decisions'     # prints nothing
nix flake check --print-build-logs && nix build .#vm-smoke
git commit -m "feat!: remove deprecated names (0.4.0)"
git push -u origin drop-compat && gh pr create --base main --title "0.4.0" --body "Remove compat layer." && gh pr merge --merge
git switch main && git pull && git tag -a v0.4.0 -m "Remove deprecated names" && git push origin v0.4.0
```
```bash
# run in: $NIXLAB
git switch main && git pull && git switch -c obs-v040
sed -i -E 's#(github:Temhr/observability/)v[0-9][^"]*#\1v0.4.0#' flake.nix && nix flake update observability
# capture2.sh reads three old names; point it at the new ones:
sed -i -E 's/services\.loki-nixlab/services.observability-loki/g; s/services\.grafana-nixlab/services.observability-grafana/g; s/services\.alloy-nixlab/services.observability-alloy/g' $BASELINE/capture2.sh
nix flake check && for h in nixnas1 nixnas2 nixace nixsun nixtop nixvat nixzen; do nix build ".#nixosConfigurations.$h.config.system.build.toplevel" --no-link || echo "FAILED: $h"; done
git commit -am "chore(observability): pin v0.4.0"
```
Roll out by §10.3 and merge by §10.4 Step 3.

### 13.2 What "1.0" means (all must be true)

| Criterion | How to check it |
|---|---|
| A release has shipped with no compat layer for at least one minor version, and nixlab runs it | `v0.4.0` tagged; nixlab pinned to it for a month |
| Every option has a description | in `flake/ci/docs.nix` change `warningsAreErrors = false;   # flip to true in Part 13` to `warningsAreErrors = true;`, then `nix build .#options-doc`; each error names an option to describe; fix until it builds |
| `vm-smoke` is green on stable **and** unstable nixpkgs in CI | add a second job (copy the `check` job, use `inputs.nixpkgs-unstable`) and see both green |
| The restore drill and rotation runbook are written and drilled | §11.4 and §11.5 done |
| Someone (or a fresh VM) builds `examples/minimal` from the README alone | follow the README quick start on a machine that has never seen this repo |
| `public-api.md` states the semver policy | a "Versioning" paragraph: breaking changes only in minor releases before 1.0 and major releases after; deprecation lasts one minor release with a warning |
| `docs/runbooks/_todo.txt` is empty | `wc -c docs/runbooks/_todo.txt` prints 0 |
| The hardening table is recorded | `docs/security/hardening.md` filled (§11.3) |

### 13.3 Deliberately not in this guide

Windows or Darwin support (the modules are Linux-only), a federated multi-host Prometheus design (each host is self-contained by design), dashboards beyond the two that exist, and a binary cache for the checks. Each is a feature, not a migration step.

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
