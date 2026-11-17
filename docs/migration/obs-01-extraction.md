# Observability Flake — Guide 1 of 3: Extraction

> **Milestone goal:** move the existing observability implementation out of `nixlab` into its own flake **with behaviour preserved**, and have `nixlab` consume it as a pinned input under the *same module names it uses today*.
>
> **Not in this milestone:** removing `nixlabLib`, `hostMeta`, `nixlab.mainUser`, or renaming anything. Those are Guide 2. Guide 1 is allowed a short, explicit list of *seams* (§0.3) and nothing else.
>
> **Status of this document:** written from a read of the ~131 uploaded files. The Nix snippets have **not** been evaluated against your tree. Treat each step's *Verify* block as the source of truth, and expect to fix small things.

---

## 0. Read this first

### 0.1 Roadmap

| Guide | Milestone | Rule of thumb |
|---|---|---|
| **1 (this)** | Extraction | Move files; change only what *cannot* work in a different flake. |
| 2 | Decoupling | Delete every seam in §0.3; establish the public option/module contract. |
| 3 | Evolution | Rename, flatten layout, new tests, security and operations work. |

Do not start Guide 2 until the exit criteria in §9 are met and the soak period is over.

### 0.2 Conventions

Variables used throughout (set them in your shell):

```bash
export NIXLAB=~/nixlab                 # existing repo
export OBS=~/observability             # new repo (created in Part 3)
export OBS_GH=Temhr/observability      # PLACEHOLDER: decide the real name now, it ends up in alert runbook URLs
export BASELINE=~/obs-baseline         # captured outputs from before the change
```

Every step has **Do / Verify / Commit**. Commit messages use `type(scope): subject` (`chore`, `feat`, `refactor`, `ci`, `docs`). Never combine a *move* and an *edit* in one commit — it makes `git log --follow` and review useless.

**Keep this guide under version control.** First action of the whole migration:

```bash
cd $NIXLAB && git switch -c obs-extraction
mkdir -p docs/migration
cp /path/to/guide-1-extraction.md docs/migration/obs-01-extraction.md
git add docs/migration && git commit -m "docs(migration): add observability extraction guide 1"
```

Tick the progress checklist in §10 as you go, committing the tick with the work it covers. When the new repo exists (Part 3) copy the guides into `$OBS/docs/development/migration/` so they follow the code.

### 0.3 Decisions made for you (and why)

These deviate from, or sharpen, the design document. Each is deliberate.

| # | Decision | Reason |
|---|---|---|
| D1 | **Keep the directory layout identical** (`modules/nixos/observability/…`, `stacks/`, `sops/`, `flake/ci/`, `bin/`, `docs/`). Do **not** flatten to `modules/nixos/prometheus/…` yet. | Zero path renames means `git filter-repo` needs no `--path-rename`, `git log --follow` works, and store paths embedding `…/observability/grafana/dashboards` stay identical so parity diffs are quiet. Flatten in Guide 3. |
| D2 | **Keep every module name and option namespace** (`servc--loki-nixlab`, `services.loki-nixlab.*`, `services.nixlab-observability.*`, …). | Host files and profiles keep working untouched. Renames come later with `mkRenamedOptionModule` aliases. |
| D3 | **Keep the `nixlabLib` / `hostMeta` / `allHosts` special-args contract for now.** The new repo gets a *verbatim copy* of `nixlabLib` and a test harness that injects it. | Replacing the helpers is the heart of Guide 2. Doing it here would mix refactor with extraction and destroy parity. |
| D4 | **Pin `nixlab` to a git tag of the observability repo, never a branch.** | See §7.1 hazard: your hosts auto-update. |
| D5 | **Hosts are validated by a test harness, not by `self.nixosConfigurations`.** | `flake/ci/observability-checks.nix` currently evaluates real hosts (`nixnas1`, `nixsun`). The new flake has no hosts. |

### 0.4 The seams (the *only* things changed besides moving files)

Each seam is tagged `# M2-REMOVE` in code so Guide 2 can find it with `git grep M2-REMOVE`.

| Seam | What breaks without it | Fix in Guide 1 | Removed in |
|---|---|---|---|
| **S1** `nixlabLib` special arg | Every service module takes `nixlabLib` as a module argument; a bare flake doesn't provide it. | Copy `flake/nixos-lib.nix` verbatim into the new repo; test harness injects it. Real `nixlab` hosts keep injecting their own copy. | Guide 2 |
| **S2** `hostMeta`, `allHosts` special args | Stack reads `hostMeta.address/gateway` and `self.lib.hostsMeta`. | `hostMeta ? {}` already defaults; replace `self.lib.hostsMeta` with the `allHosts ? {}` arg. Harness injects stubs. | Guide 2 |
| **S3** `self` used as a **NixOS module argument** in `sops/alertmanager.nix` and `sops/grafana.nix` | `self` there comes from `specialArgs`, i.e. *nixlab's* `self`. After extraction it would silently resolve to the wrong flake. | Capture `self` from the outer flake-parts function instead. **This is a real bug fix, not a shim.** | n/a (permanent) |
| **S4** `self.lib.serviceRegistry` in the stack | The registry lives in nixlab's homepage module. | New option `probes.tcpTargets` (default `[]`); a nixlab-side adapter fills it from the registry. | Guide 2 |
| **S5** `secretsFile` defaults (`./alertmanager.env`, `./grafana.yaml`) | Encrypted files stay in `nixlab`; the defaults would point at non-existent files in the new repo. | Remove the defaults; the nixlab adapter sets them. | Guide 2 (becomes optional sops integration) |
| **S6** `config.nixlab ? mainUser` in 5 modules | This expression throws `attribute 'nixlab' missing` if no `nixlab` option exists at all (the `?` operator evaluates `config.nixlab` first). | Don't edit the modules; harness declares a stub `options.nixlab.mainUser`. | Guide 2 |
| **S7** `runbookBase` URL hard-coded to `Temhr/nixlab` | Runbooks move; URLs would 404. | Change the one string. **This is the single intended difference in generated config.** | Guide 3 (becomes an option) |
| **S8** Port defaults live in `nixlab/modules/ports.nix` alongside ~10 unrelated services | The obs modules `imports = [self.nixosModules.systm--ports-loki]` etc. | Move only the five observability port modules to the new repo; delete them from `nixlab`. | Guide 2 |

---

## Part 1 — Pre-flight: baseline the current system

Skipping this part makes parity (Part 6) unprovable. Do it all.

### 1.1 Freeze and tag

```bash
cd $NIXLAB
git status                              # must be clean
git tag pre-obs-extraction
```

**Verify:** `git tag -l pre-obs-extraction` prints the tag.

### 1.2 Baseline `nix flake check` and builds

```bash
nix flake check 2>&1 | tee $BASELINE/flake-check.txt     # mkdir -p $BASELINE first
for h in nixnas1 nixnas2 nixace nixsun nixtop nixvat nixzen; do
  mkdir -p $BASELINE/$h
  nix build ".#nixosConfigurations.$h.config.system.build.toplevel" -o $BASELINE/$h/toplevel
done
```

**Verify:** all seven `toplevel` symlinks exist. Write any *pre-existing* failures into `$BASELINE/known-issues.md` — do not let them be blamed on the extraction later.

### 1.3 Capture content-level fingerprints

Closure diffs tell you *that* something changed; these dumps tell you *what*. Save as `$BASELINE/capture.sh` (it is re-run unchanged in Part 6; the `or` fallback makes it work before and after):

```bash
#!/usr/bin/env bash
# usage: capture.sh <outdir>   — run from the nixlab repo root, on a clean committed tree
set -euo pipefail
out=$1; mkdir -p "$out"
for h in nixnas1 nixnas2 nixace nixsun nixtop nixvat nixzen; do
  d=$out/$h; mkdir -p "$d"
  nix build ".#nixosConfigurations.$h.config.system.build.toplevel" -o "$d/toplevel"
  ev() {  # $1 = nix expression using `c` (host config) and `f` (flake)
    nix eval --json --impure --expr \
      "let f = builtins.getFlake \"git+file://$PWD\"; c = f.nixosConfigurations.$h.config; in $1" | jq -S .
  }
  ev 'let r = f.lib.prometheusRendered or f.inputs.observability.lib.prometheusRendered; in r {config = c; lib = f.inputs.nixpkgs.lib;}' > "$d/prometheus-rendered.json"
  ev 'c.services.prometheus.alertmanager.configuration'            > "$d/alertmanager.json"
  ev 'c.services.loki-nixlab.ruler.groups'                         > "$d/loki-ruler.json"
  ev 'c.services.grafana-nixlab.provisioning.datasources'          > "$d/datasources.json"
  ev 'c.services.alloy-nixlab.extraConfig'                         > "$d/alloy-extra.json"
  ev 'c.networking.firewall.interfaces'                            > "$d/firewall-ifaces.json"
  ev 'c.networking.firewall.allowedTCPPorts'                       > "$d/firewall-tcp.json"
  ev 'builtins.mapAttrs (_: u: {inherit (u) uid group extraGroups;}) (builtins.intersectAttrs {loki=1; prometheus=1; grafana=1; ntfy=1; alloy=1;} c.users.users)' > "$d/users.json"
  ev 'builtins.mapAttrs (_: s: {inherit (s) serviceConfig; unitConfig = s.unitConfig or {}; after = s.after or []; wants = s.wants or []; requires = s.requires or [];}) (builtins.intersectAttrs {prometheus=1; loki=1; alloy=1; grafana=1; alertmanager=1; ntfy=1; prometheus-node-exporter=1; loki-permissions=1;} c.systemd.services)' > "$d/units.json"
done
```

```bash
chmod +x $BASELINE/capture.sh && $BASELINE/capture.sh $BASELINE/before
```

**Verify:** `ls $BASELINE/before/nixnas1` shows eleven files, none empty. If one `ev` line fails (a value isn't JSON-serialisable, an option path differs on one host), fix or drop *that line*, and keep the same script for the "after" run.

### 1.4 Runtime baseline on one host

On the host you will migrate first (recommend a low-risk desktop such as `nixvat`, **not** `nixnas1`, which carries ZFS and the NAS role):

```bash
bin/mon-check.sh --fire-test            # needs MON_NTFY_AUTH if ntfy auth is on
bin/mon-snapshot.sh /tmp/snap-before
for u in loki prometheus grafana ntfy alloy; do id $u; done > /tmp/snap-before/ids.txt
```

**Verify:** `mon-check.sh` exits 0. Copy `/tmp/snap-before` off the host.

### 1.5 Dependency inventory (find what the upload could not show)

Your upload contains the observability files, not the whole repo. Run these in `$NIXLAB` and save the output to `$BASELINE/inventory.txt`; **read every hit before continuing**:

```bash
# Other hosts or profiles overriding obs options (the upload only has nixnas1, nixzen, three profiles)
git grep -nE 'services\.(grafana|loki|prometheus|alertmanager|ntfy|alloy|host-exporters|maintenance-log|observability-backup)-nixlab|nixlab-observability' -- hosts home hardware modules/nixos/dashboards

# Everything that consumes obs-owned flake.lib entries
git grep -nE 'self\.lib\.(prometheusRendered|prometheusMaintenanceAlerts|grafanaDashboards|maintenanceLoggerScript)'

# Everything that imports the five obs port modules
git grep -nE 'systm--ports-(ntfy|loki|grafana|prometheus|alertmanager)'

# Overlays or pkgs/ that touch obs packages (the extracted modules use the *host's* pkgs, overlays included)
git grep -nE 'grafana|prometheus|loki|alloy|ntfy|alertmanager' -- overlays pkgs

# Auto-update machinery (see §7.1)
git grep -nE 'flake update|gpull|nixos-upgrade' -- hosts/common modules
```

**Decide per hit:** moves with obs / stays in nixlab / needs a new seam. If an overlay modifies an obs package, that overlay stays in nixlab and the extracted modules will still get it (they use `pkgs` from the host) — but your *standalone* CI will test the unmodified package. Note it in `known-issues.md`.

### 1.6 Backups

Confirm `/data/backup` (from `observability-backup`) is current and included in your off-host backup. This is your rollback for Grafana/ntfy databases.

**Commit:** nothing to commit in nixlab here except the checklist tick.

---

## Part 2 — Pre-publication hygiene

Decide before the new repo exists, because history is hard to unpublish.

1. **Public or private?** The design doc assumes reusable. Two things in your files argue for care:
   - `docs/wiki/observability.md` §3 contains a host table with LAN IPs (`10.0.0.2xx`), gateway and DNS, and names your hosts.
   - Hosts fetch flake inputs during auto-upgrade. A **private** repo requires `access-tokens` configured for the root nix daemon on every host, or `nixos-upgrade` will fail with an auth error.
2. **Recommendation:** start **private**, add a deploy-token setup, scrub the doc in Guide 3, then consider going public. If you go public now, scrub that table first (Part 3.3).
3. **Licence:** pick one before the first public push (e.g. MIT/Apache-2.0). Without one the code is "all rights reserved".

---

## Part 3 — Create the new repository, **with history**

### 3.1 Extract history with `git filter-repo`

Use a **fresh clone** (filter-repo refuses to run on a working repo, and you must not rewrite nixlab):

```bash
nix shell nixpkgs#git-filter-repo -c bash -c '
  git clone --no-local $NIXLAB $OBS && cd $OBS
  git filter-repo \
    --path modules/nixos/observability/ \
    --path stacks/observability.nix \
    --path sops/alertmanager.nix \
    --path sops/grafana.nix \
    --path bin/mon-check.sh --path bin/mon-snapshot.sh --path bin/mon-unitdiff.sh \
    --path docs/runbooks/ \
    --path docs/wiki/observability.md \
    --path flake/ci/observability-checks.nix \
    --path flake/ci/_tests/
'
```

Deliberately **excluded** (do not add them): `sops/*.env`, `sops/*.yaml` (encrypted secrets stay in nixlab), `sops/homepage.nix` (homepage is not observability), `modules/ports.nix` (mixed; split by hand in 3.4), `flake/nixos-lib.nix` (shared; *copied* in 3.5), `flake/ci/checks.nix`.

**Verify:**

```bash
cd $OBS
git ls-files | head -80                          # only the paths above
git log --oneline | wc -l                        # history exists
git log --all --oneline -- 'sops/*.env' 'sops/*.yaml'   # must print nothing
git grep -n 'ENC\[' $(git rev-list --all) -- . | head    # must print nothing
nix run nixpkgs#gitleaks -- detect --source . --log-opts="--all"   # no findings
```

Because nothing was renamed, `git log --follow modules/nixos/observability/loki/default.nix` shows the full history. (Files that lived at *older* paths before your last reorganisation are not carried; that is acceptable.)

> `filter-repo` removes `origin`. The old history stays intact in nixlab; that is your safety net.

### 3.2 Remove the now-misplaced doc IPs (only if going public now)

Edit the host table in `docs/wiki/observability.md` §3 to remove addresses. Separate commit: `docs: scrub host addresses`. (History still contains them; for a public repo also rewrite history, e.g. `git filter-repo --replace-text`, **before** first push.)

### 3.3 Scaffold: `flake.nix`

`$OBS/flake.nix` — mirrors nixlab's thin-root pattern, with only the inputs the extracted code needs:

```nix
{
  description = "Observability stack (Prometheus, Loki, Alloy, Grafana, Alertmanager, ntfy) as composable NixOS modules";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux"];
      imports = [
        (inputs.import-tree ./flake)
        (inputs.import-tree ./modules)
        (inputs.import-tree ./sops)
        (inputs.import-tree ./stacks)
      ];
    };
}
```

Notes:
- `nixpkgs` = nixlab's `nixpkgs-stable` channel; `nixpkgs-unstable` is for the second CI host. Keep the channels aligned with nixlab so Part 5 validates what you actually run.
- `systems` is `x86_64-linux` only. The modules are Linux-specific and your hosts are all x86_64; claim nothing more.
- `import-tree` ignores any path containing `_` — that is how `flake/ci/_harness/` and `flake/ci/_tests/` stay out of the module graph.

### 3.4 Scaffold: the `flake.lib` schema and the split port modules

`$OBS/flake/schema/options.nix` (copy of nixlab's, minus `homeModules`):

```nix
{lib, ...}: {
  options.flake.lib = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = {};
    description = "Library functions and metadata exported by this flake.";
  };
}
```

`$OBS/modules/nixos/observability/ports.nix` — **only** the five observability entries lifted from `nixlab/modules/ports.nix`, byte-for-byte (seam **S8**):

```nix
# Observability port defaults (mkDefault). Moved from nixlab/modules/ports.nix.
{...}: {
  flake.nixosModules.systm--ports-ntfy = {lib, ...}: {
    services.ntfy-nixlab.port = lib.mkDefault 2586;
  };
  flake.nixosModules.systm--ports-loki = {lib, ...}: {
    services.loki-nixlab.port = lib.mkDefault 3100;
    services.loki-nixlab.grpcPort = lib.mkDefault 9096;
    services.loki-nixlab.alloyPort = lib.mkDefault 12345;
  };
  flake.nixosModules.systm--ports-grafana = {lib, ...}: {
    services.grafana-nixlab.port = lib.mkDefault 3101;
  };
  flake.nixosModules.systm--ports-prometheus = {lib, ...}: {
    services.prometheus-nixlab.port = lib.mkDefault 9090;
    services.prometheus-nixlab.blackboxPort = lib.mkDefault 9115;
    services.prometheus-nixlab.smartctlPort = lib.mkDefault 9633;
    services.prometheus-nixlab.systemdExporterPort = lib.mkDefault 9558;
  };
  flake.nixosModules.systm--ports-alertmanager = {lib, ...}: {
    services.alertmanager-nixlab.port = lib.mkDefault 9093;
    services.alertmanager-nixlab.clusterPort = lib.mkDefault 9094;
  };
}
```

> Keep the precedence rule from `ports.nix`'s header comment in your head: host plain assignment beats `mkDefault` here beats the option default.

### 3.5 Scaffold: the `nixlabLib` copy (seam S1)

```bash
cd $OBS
cp $NIXLAB/flake/nixos-lib.nix flake/nixos-lib.nix
sed -i '1i # M2-REMOVE (S1): verbatim copy of nixlab/flake/nixos-lib.nix. Do NOT edit while nixlab keeps its own copy; Guide 2 replaces this with observability-owned helpers.' flake/nixos-lib.nix
```

It registers `flake.lib.nixlabLib`, which the harness uses. Keep it byte-identical apart from that comment: any behavioural drift between the two copies invalidates parity.

### 3.6 Scaffold: hygiene files

```bash
cat > .gitignore <<'EOF'
result
result-*
.direnv/
.pre-commit-config.yaml
EOF
```

Add `LICENSE` (Part 2) and a short `README.md`: what it is, "extraction in progress", link to `docs/development/migration/`.

Copy the pre-commit config from nixlab `flake/ci/checks.nix` (alejandra, deadnix, merge-conflict, no-submodules, large-files). `src = ./../..` stays correct at the same depth:

`$OBS/flake/ci/checks.nix`:

```nix
{inputs, ...}: {
  perSystem = {
    pkgs,
    system,
    ...
  }: {
    formatter = pkgs.alejandra;
    checks.pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run {
      src = ./../..;
      hooks = {
        alejandra.enable = true;
        deadnix.enable = true;
        check-merge-conflicts.enable = true;
        forbid-new-submodules.enable = true;
        check-added-large-files.enable = true;
      };
    };
    devShells.default = pkgs.mkShell {
      packages = [pkgs.prometheus.cli pkgs.prometheus-alertmanager pkgs.remarshal pkgs.gettext pkgs.jq pkgs.shellcheck pkgs.alejandra pkgs.deadnix];
    };
  };
}
```

**Verify and commit** (separately from the history, so the filtered commits stay pure):

```bash
git add -A && git commit -m "chore: scaffold flake, schema, split ports, nixlabLib copy, hygiene"
```

---

## Part 4 — Make the extracted code evaluate on its own

At this point `nix flake show` will *evaluate* but modules will fail when instantiated. Work through the seams one commit each. The first commit of each pair is the edit; do **not** reformat unrelated lines.

### 4.1 S3 — fix `self` in the two sops modules

In **both** `sops/alertmanager.nix` and `sops/grafana.nix`, change the outer function to take `self`, and remove `self` from the inner NixOS-module argument list:

```diff
-{...}: {
+{self, ...}: {
   flake.nixosModules.nsops--alertmanager = {
     config,
     lib,
-    self,
     ...
   }: let
```

Same for `nsops--grafana`. This is the change that stops these modules depending on whichever `self` the host builder injects.

### 4.2 S5 — drop the `secretsFile` defaults

In both modules remove `default = ./…;` **and** `defaultText = …;` from the `secretsFile` option, and replace the "defaults to … co-located" sentence in the description with: `Required when the service is enabled; supplied by the consumer (the encrypted file is not part of this repository).` Leave `type = lib.types.path;`.

### 4.3 S4 + S2 — edit the stack (`stacks/observability.nix`)

Three small edits.

**(a)** Module arguments — add `allHosts`:

```diff
     flake.nixosModules.stack--observability = {
       config,
       lib,
       hostMeta ? {},
+      allHosts ? {}, # M2-REMOVE (S2)
       ...
     }: let
```

**(b)** Remove the registry. Delete these lines from the `let` block:

```nix
      registry = self.lib.serviceRegistry {inherit config;};
      registryTcpTargets =
        lib.mapAttrsToList (_: e: "127.0.0.1:${toString e.port}")
        (lib.filterAttrs (k: _: registry.enabled.${k} or false) (registry.endpoints or {}));
```

…add the option next to `tcpFromRegistry` (keep that option for now):

```nix
          tcpTargets = lib.mkOption {
            # M2-REMOVE (S4): filled by the nixlab adapter from the homepage service registry.
            type = lib.types.listOf lib.types.str;
            default = [];
            example = ["127.0.0.1:8123"];
            description = "host:port TCP probe targets used when tcpFromRegistry is true.";
          };
```

…and in `config`, change the blackbox block:

```diff
         services.prometheus-nixlab.maintenance.exporters.blackbox = {
           icmpTargets = lib.mkDefault (
             lib.optional (cfg.probes.gateway != null) cfg.probes.gateway
             ++ lib.filter (a: a != (hostMeta.address or ""))
-            (map (h: self.lib.hostsMeta.${h}.address) cfg.probes.hosts)
+            (map (h: allHosts.${h}.address) cfg.probes.hosts)
           );
-          tcpTargets = lib.mkIf cfg.probes.tcpFromRegistry (lib.mkDefault registryTcpTargets);
+          tcpTargets = lib.mkIf cfg.probes.tcpFromRegistry (lib.mkDefault cfg.probes.tcpTargets);
         };
```

`self` is still used in the stack's `imports = [self.nixosModules.…]`, which now correctly resolves to the observability flake (those are all observability-owned names). Do not touch anything else.

### 4.4 S7 — the runbook URL (the one intended content change)

`modules/nixos/observability/prometheus/_internals/rendered.nix`:

```diff
-      runbookBase = "https://github.com/Temhr/nixlab/blob/main/docs/runbooks";
+      # Changed in the extraction commit; every other generated byte must match baseline.
+      runbookBase = "https://github.com/Temhr/observability/blob/main/docs/runbooks";   # use your real $OBS_GH
```

Also update the same URL mentioned in `docs/wiki/observability.md` (§5.x "Rules … `runbookBase`").

### 4.5 Commit the seams

```bash
git add -A
git commit -m "refactor(sops): capture self from flake-parts scope, not module args (S3)"   # if you split into separate commits, do so
```

Prefer **one commit per seam** (S3, S5, S4+S2, S7).

### 4.6 The test harness (`flake/ci/_harness/default.nix`)

This replaces `self.nixosConfigurations.<host>`: a synthetic host that supplies the same special args and stubs nixlab supplies.

```nix
# Test harness for the extraction milestone. Supplies, as nixlab does, the
# special args the modules still expect (M2-REMOVE: S1, S2, S6).
{
  inputs,
  self,
}: {
  mkTestHost = {
    nixpkgs ? inputs.nixpkgs,
    modules ? [],
  }:
    nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      # NOTE: `self` and `inputs` are deliberately NOT passed. If any module still
      # needs them, evaluation fails here — that is the S3 regression test.
      specialArgs = {
        nixlabLib = self.lib.nixlabLib; # S1
        hostMeta = {
          address = "192.0.2.10";
          gateway = "192.0.2.1";
          ethIface = "eth0";
          wifiIface = "";
        }; # S2
        allHosts = {}; # S2
      };
      modules =
        [
          inputs.sops-nix.nixosModules.sops
          self.nixosModules.stack--observability
          ({
            lib,
            pkgs,
            ...
          }: {
            # S6: stand-in for nixlab's real option. Empty string means "no main user".
            options.nixlab.mainUser = lib.mkOption {
              type = lib.types.str;
              default = "";
            };
            config = {
              networking.hostName = "testhost";
              system.stateVersion = "24.11";
              boot.loader.grub.enable = false;
              fileSystems."/" = {
                device = "none";
                fsType = "tmpfs";
              };
              # sops-nix needs a key source and (without this) a valid encrypted file at eval time.
              sops.age.keyFile = "/var/lib/sops-nix/key.txt";
              sops.validateSopsFiles = false;
              services.alertmanager-nixlab.secretsFile = pkgs.writeText "alertmanager.env" "";
              services.grafana-nixlab.secretsFile = pkgs.writeText "grafana.yaml" "";
            };
          })
        ]
        ++ modules;
    };

  # Everything on. Exercises every optional branch the stack has.
  fullStack = {
    services.nixlab-observability = {
      enable = true;
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

  minimalStack = {
    services.nixlab-observability.enable = true;
  };
}
```

> If evaluation of `fullStack` complains about a missing option or a secret, fix the *harness*, not the module — the harness is the stand-in for the host. The only legitimate module edits in this milestone are §4.1–§4.4.

### 4.7 Shared per-host checks (`flake/ci/host-checks.nix`)

Move the per-host derivations out of `observability-checks.nix` into a function so **both** repos can run exactly the same checks (nixlab on real hosts, this repo on harness hosts). The bodies are lifted unchanged from the existing `perHost`:

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

### 4.8 Edit `flake/ci/observability-checks.nix`

Keep: `runbook-coverage`, `dashboard-lint`, `maintenance-log-shellcheck`, `prom-rules-all-features`, `prom-rule-tests` **unchanged** (they use `${self}/docs/runbooks`, `self.lib.grafanaDashboards`, `self.lib.maintenanceLoggerScript`, `${./_tests/prometheus}` — all resolve correctly inside the new repo because paths are unchanged).

Replace only the `perHost` machinery. Delete the `perHost` binding and change the fold:

```diff
-      perHost = host: let …
-      in { … };
+      harness = import ./_harness {inherit inputs self;};
+      hosts = {
+        stable = harness.mkTestHost {modules = [harness.fullStack];};
+        unstable = harness.mkTestHost {
+          nixpkgs = inputs.nixpkgs-unstable;
+          modules = [harness.fullStack];
+        };
+        minimal = harness.mkTestHost {modules = [harness.minimalStack];};
+      };
```

```diff
-        (lib.foldl' (acc: host: acc // perHost host) {} ["nixnas1" "nixsun"])
+        (lib.foldl' (acc: name:
+            acc
+            // self.lib.observabilityHostChecks {
+              inherit pkgs name;
+              hostConfig = hosts.${name}.config;
+            }) {} ["stable" "unstable"])
+        // {
+          # Whole-system evaluation + build of each harness host.
+          toplevel-stable = hosts.stable.config.system.build.toplevel;
+          toplevel-minimal = hosts.minimal.config.system.build.toplevel;
+        }
```

Also change the file's argument header to `{self, inputs, lib, ...}:` and drop the now-unused `prometheusRendered` / `toJson`-for-host bindings if `deadnix` flags them. Update the stale comment ("hosts-meta.nix") to point at the harness.

### 4.9 Optional but recommended: runnable scripts as flake apps

Hosts will no longer have a `nixlab` checkout containing `bin/`. `$OBS/flake/ci/apps.nix`:

```nix
{...}: {
  perSystem = {pkgs, ...}: let
    mk = name: file: {
      type = "app";
      meta.description = "Observability ${name}";
      program = toString (pkgs.writeShellScript name (builtins.readFile file));
    };
  in {
    apps.mon-check = mk "mon-check" ../../bin/mon-check.sh;
    apps.mon-snapshot = mk "mon-snapshot" ../../bin/mon-snapshot.sh;
    apps.mon-unitdiff = mk "mon-unitdiff" ../../bin/mon-unitdiff.sh;
  };
}
```

`bin/*.sh` remains the source of truth. These apps rely on `curl`, `jq`, `systemctl`, `ss` being on the host's `PATH` (as today). Making them hermetic is a Guide 3 item.

### 4.10 Verify the new repo standalone

```bash
cd $OBS
git add -A                      # git+file/flake eval ignores UNTRACKED files — add new files first
nix flake show
nix flake check --print-build-logs
nix build .#checks.x86_64-linux.toplevel-stable
```

**Verify (all must hold):**
- `nix flake check` passes: pre-commit, `prom-config-stable/unstable`, `prom-rules-*`, `alertmanager-config-*`, `prom-rules-all-features`, `prom-rule-tests`, `runbook-coverage`, `dashboard-lint`, `maintenance-log-shellcheck`, `toplevel-*`.
- `nix eval .#nixosModules --apply builtins.attrNames` lists at least: `stack--observability`, `servc--{prometheus,alertmanager,ntfy,loki,alloy,grafana}-nixlab`, `systm--{host-exporters,maintenance-log,observability-backup}-nixlab`, `nsops--{alertmanager,grafana}`, `systm--ports-{ntfy,loki,grafana,prometheus,alertmanager}`.
- `git grep -nE 'hostsMeta|serviceRegistry|self\.nixosConfigurations|\bnixlab/' -- modules stacks sops flake` returns nothing except `# M2-REMOVE` lines and comments.

**Commit:** `ci: add harness-based checks, shared host-checks, apps`. Then push (private) and tag:

```bash
git remote add origin git@github.com:$OBS_GH.git
git push -u origin main
git tag v0.1.0-rc1 && git push origin v0.1.0-rc1
```

> **Rule:** from now until Part 8 completes, do not edit `nixos-lib.nix` in *either* repo, and do not change observability behaviour in nixlab.

---

## Part 5 — Wire `nixlab` to the new flake

Work on `obs-extraction` in nixlab. **Do not merge to `main` yet** (§7.1).

### 5.1 Add the input (development form first)

```diff
+      observability = {
+        url = "git+file:///home/<you>/observability?ref=main";   # dev only; replaced by the tag in 5.8
+        inputs.nixpkgs.follows = "nixpkgs";
+        inputs.nixpkgs-unstable.follows = "nixpkgs-unstable";
+        inputs.sops-nix.follows = "sops-nix";
+        inputs.flake-parts.follows = "flake-parts";
+      };
```

Only add `follows` for inputs the obs flake actually declares (a follows for a non-existent input produces a warning). Note on what `follows` really buys you: your hosts build with **their own** `pkgs` (`nixpkgs-stable` / `nixpkgs-unstable` via `mkHost`), and the obs modules use that `pkgs`. The obs flake's own `nixpkgs` input only affects its checks and `lib`; `follows` just avoids a duplicate lock entry.

```bash
nix flake lock          # adds only the new input. NEVER run `nix flake update` here.
git diff flake.lock     # confirm no other input moved
```

`git+file` sees **only git-tracked files** in the obs repo; commit there before re-locking (`nix flake lock --update-input observability`).

### 5.2 Re-export the modules under the same names

`$NIXLAB/flake/observability.nix`:

```nix
{inputs, ...}: {
  # Surface the observability flake's modules as if they were native nixlab modules.
  # Names are unchanged, so existing `self.nixosModules.*` references keep working.
  flake.nixosModules = inputs.observability.nixosModules;
}
```

> **Order matters:** do 5.3 (delete the originals) in the *same commit* as this file. `flake.nixosModules` is `lazyAttrsOf deferredModule`; if both the old file and the re-export define `servc--loki-nixlab`, the two definitions are **merged** (both imported), producing duplicate-option errors rather than a clean "defined twice".

### 5.3 Delete what moved

```bash
cd $NIXLAB
git rm -r modules/nixos/observability
git rm stacks/observability.nix sops/alertmanager.nix sops/grafana.nix
git rm bin/mon-check.sh bin/mon-snapshot.sh bin/mon-unitdiff.sh
git rm flake/ci/observability-checks.nix
git rm -r flake/ci/_tests
git rm -r docs/runbooks
git rm docs/wiki/observability.md
```

**Keep** in nixlab: `sops/alertmanager.env`, `sops/grafana.yaml`, `.sops.yaml` (path regexes `sops/alertmanager\.env$` etc. still match), `sops/homepage.*`, `flake/nixos-lib.nix`, `flake/ci/checks.nix`.

> If your `git grep` in §1.5 found other files that referenced obs paths (e.g. a nixlab doc or `README.md` linking `docs/runbooks`), fix those links now.

### 5.4 Remove the observability ports from nixlab

Delete the five `systm--ports-{ntfy,loki,grafana,prometheus,alertmanager}` blocks from `modules/ports.nix`. Leave the rest. (Seam S8: they now come from the observability flake.)

### 5.5 The adapter (`stacks/observability-nixlab.nix`)

One module that carries the two nixlab-only facts the obs flake must not know: where the encrypted files live (S5) and the service registry (S4):

```nix
{self, ...}: {
  flake.nixosModules.stack--observability-nixlab = {
    config,
    lib,
    ...
  }: let
    registry = self.lib.serviceRegistry {inherit config;};
    registryTcpTargets =
      lib.mapAttrsToList (_: e: "127.0.0.1:${toString e.port}")
      (lib.filterAttrs (k: _: registry.enabled.${k} or false) (registry.endpoints or {}));
  in {
    imports = [self.nixosModules.stack--observability];

    # S4: same list the stack used to compute internally.
    services.nixlab-observability.probes.tcpTargets = lib.mkDefault registryTcpTargets;

    # S5: encrypted files stay in nixlab.
    services.alertmanager-nixlab.secretsFile = lib.mkDefault ../sops/alertmanager.env;
    services.grafana-nixlab.secretsFile = lib.mkDefault ../sops/grafana.yaml;
  };
}
```

Then, in `hosts/common/profile-base.nix`, replace the single import:

```diff
-        self.nixosModules.stack--observability
+        self.nixosModules.stack--observability-nixlab
```

Nothing else in host or profile files changes — `services.nixlab-observability.*`, `services.grafana-nixlab.extraDashboards`, `services.prometheus-nixlab.maintenance.expectedMounts` etc. keep their names.

### 5.6 Keep real-host validation in nixlab

`$NIXLAB/flake/ci/observability-integration.nix`:

```nix
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
  }: {
    # Same three checks as before, run by the observability flake's own implementation
    # against nixlab's real hosts (one per nixpkgs channel). Names are unchanged.
    checks = lib.optionalAttrs (system == "x86_64-linux") (
      lib.foldl' (acc: host:
        acc
        // inputs.observability.lib.observabilityHostChecks {
          inherit pkgs;
          name = host;
          hostConfig = self.nixosConfigurations.${host}.config;
        }) {} ["nixnas1" "nixsun"]
    );
  };
}
```

### 5.7 Evaluate and check

```bash
git add -A
nix flake check
for h in nixnas1 nixnas2 nixace nixsun nixtop nixvat nixzen; do
  nix build ".#nixosConfigurations.$h.config.system.build.toplevel" --no-link || echo "FAIL $h"
done
```

**Verify:** all green; `prom-config-nixnas1` etc. appear in `nix flake show`.

**Commit:** one commit, `refactor(observability): consume extracted observability flake`.

### 5.8 Pin to a tag, not a branch

After Part 6 passes, tag the obs repo (`v0.1.0`) and switch the input:

```diff
-        url = "git+file:///home/<you>/observability?ref=main";
+        url = "github:Temhr/observability/v0.1.0";
```

```bash
nix flake lock --update-input observability
```

---

## Part 6 — Parity: prove nothing changed

Run `capture.sh` (from §1.3) on the migrated nixlab tree, committed and clean:

```bash
cd $NIXLAB && git status --short       # clean
$BASELINE/capture.sh $BASELINE/after
diff -ru $BASELINE/before $BASELINE/after -x toplevel > $BASELINE/parity.diff; wc -l $BASELINE/parity.diff
```

### 6.1 Expected vs. unexpected differences

| Where | Expected? | Meaning |
|---|---|---|
| `prometheus-rendered.json`, `runbook` annotation URLs | **Yes — the only intended content change** (S7) | Every rule's `annotations.runbook` points at the new repo. |
| `units.json`: `/nix/store/<hash>-…` prefixes | Yes, **hashes only** | Source tree changed. Compare with hashes normalised: `sed -E 's#/nix/store/[a-z0-9]{32}-#/nix/store/#g'`. |
| `units.json`: a `…-source/modules/nixos/observability/grafana/dashboards` path | Yes (hash part only) | Same relative path thanks to D1. |
| `alertmanager.json`, `loki-ruler.json`, `datasources.json`, `alloy-extra.json` | **No** | Any difference is a regression (typically a lost seam). |
| `firewall-*.json`, `users.json` (UIDs 740–744 etc.) | **No** | State-compat break. |
| Any `ExecStart*`/`preStart` store path whose **basename** is `loki.json`, `loki-rules.json`, or other `builtins.toFile` outputs | Hash **must be identical** | `toFile` paths are content-addressed; a changed hash means changed content. |

Normalised comparison for units:

```bash
n(){ sed -E 's#/nix/store/[a-z0-9]{32}-#/nix/store/#g' "$1"; }
for h in nixnas1 nixnas2 nixace nixsun nixtop nixvat nixzen; do
  diff <(n $BASELINE/before/$h/units.json) <(n $BASELINE/after/$h/units.json) && echo "$h units OK"
done
```

### 6.2 Closure and unit-file diff (uses your existing script)

```bash
for h in nixnas1 nixsun nixvat; do
  bash <(git show pre-obs-extraction:bin/mon-unitdiff.sh) $BASELINE/before/$h/toplevel $BASELINE/after/$h/toplevel
done
```

`nix store diff-closures` should show **no package version changes**; unit-file diffs should be limited to store-path churn and the runbook URL.

### 6.3 Exit criterion for Part 6

`parity.diff` is explained line-by-line by the table in §6.1. **Write the explanation into `$OBS/docs/development/migration/parity-report-1.md`** (commit it). Unexplained → stop and find the missing seam; do not "accept and move on".

---

## Part 7 — Deploy and soak

### 7.1 Hazard: your hosts update themselves

`profile-base` imports `hosts--autom--flake-update`, `hosts--autom--nixlab-gpull` and `hosts--autom--nixos-upgrade`. I could not see those modules, but by name they pull the repo and/or update `flake.lock` and rebuild. Consequences for this migration:

1. **Merging `obs-extraction` to `main` rolls it out to every host automatically.** Test on one host from the branch first (7.2); merge only when satisfied.
2. **A branch-pinned input drifts.** If `flake-update` runs `nix flake update`, an input pointing at `main` moves with every obs commit. Pin the **tag** (5.8). Tags don't move.
3. **A private obs repo breaks hosts' fetches** unless root's `nix.conf` has an `access-tokens` entry (or the repo is public). Test this on the first host before the others.

Read those three modules before merging. If `flake-update` pushes commits, make sure it can't silently retarget the observability input.

### 7.2 Single-host canary

On the chosen host, from the branch (do not use `switch` first):

```bash
sudo nixos-rebuild test --flake $NIXLAB#nixvat        # activates without creating a boot entry
```

Then, on the host:

```bash
nix run github:$OBS_GH/v0.1.0#mon-check -- --fire-test   # or bin/mon-check.sh from a checkout
nix run github:$OBS_GH/v0.1.0#mon-snapshot -- /tmp/snap-after
diff -ru /tmp/snap-before /tmp/snap-after || true
for u in loki prometheus grafana ntfy alloy; do id $u; done | diff - /tmp/snap-before/ids.txt && echo "UIDs unchanged"
systemctl --failed
```

**Verify:**
- `mon-check` exits 0, including the end-to-end alert reaching ntfy.
- `snap` diffs show only store-path churn and the runbook URL in `alerts.yml`.
- UIDs unchanged; `systemctl --failed` empty; Grafana dashboards all present; Loki labels non-empty.
- `observability-backup.service` run succeeds: `sudo systemctl start observability-backup && ls /data/backup`.
- Secrets still resolve: `sudo test -r /run/secrets/ALERTMANAGER_ENV`.

If all good: `sudo nixos-rebuild switch --flake …`. Reboot once and re-run `mon-check` — this exercises the permission-repair oneshots and mount ordering at boot.

**Rollback (any time):** `sudo nixos-rebuild switch --rollback`, or pick the previous generation at the boot menu. For the repo: `git revert` the integration commit, or `git checkout pre-obs-extraction`. Data is untouched by all of this (state paths and UIDs are unchanged); the `/data/backup` copies exist for the two SQLite databases.

### 7.3 Staged rollout and soak

1. Canary host (≥ 3 days, covering at least one nightly backup, one alert, one reboot).
2. A second host on the *other* nixpkgs channel (stable ↔ unstable).
3. `nixnas1` last — it uses `extraDashboards = ["zfs-monitoring"]`, the `/mirror` expected mount, and has the ZFS/SCSI alert paths.
4. Merge to `main`; let auto-upgrade take the rest.
5. Soak ≥ 1 week with no regressions before cleanup.

---

## Part 8 — Close out

1. Tag the new baseline: obs `v0.1.0` (already used), nixlab `post-obs-extraction`.
2. In nixlab, replace `docs/wiki/observability.md` with a pointer file ("canonical docs now live in `<obs repo>`"). Update `README.md`'s observability section and any link to `docs/runbooks`.
3. Delete the `obs-extraction` branch after merge. Keep `pre-obs-extraction` indefinitely.
4. Fill in the **seam register** (§9.2) from `git grep M2-REMOVE` in both repos; this is Guide 2's work list.

---

## 9. Exit criteria for Guide 1

### 9.1 Checklist

- [ ] New repo evaluates; `nix flake check` green (standalone, harness hosts: stable, unstable, minimal).
- [ ] History preserved (`git log --follow` works on moved files); no secret material in history (`gitleaks` clean).
- [ ] nixlab consumes the **tagged** input; `flake.lock` diff shows only the new input.
- [ ] `nix flake check` and all seven host builds pass in nixlab.
- [ ] Parity report written; only the runbook URL differs in generated config.
- [ ] Canary host: `mon-check --fire-test` passes; UIDs/paths/ports unchanged; backup runs; survived a reboot.
- [ ] All hosts migrated; soak period completed.
- [ ] Docs: nixlab points at the new repo; runbook URLs resolve.

### 9.2 Seam register (hand-off to Guide 2)

| Seam | Location(s) | Guide 2 replacement |
|---|---|---|
| S1 `nixlabLib` | all `servc--*`, `systm--host-exporters`; `flake/nixos-lib.nix` copy | Observability-owned helper set (`mkServiceHardening`, `mkDataDirPermissionsService`, `mkWalSelfHeal`, **plus** `mkNginxVirtualHost`, `mkFirewallPorts`, `mkSslAssertion`, which five modules use — the design doc leaves this open; the answer is "yes, needed"). |
| S2 `hostMeta`/`allHosts` | `stacks/observability.nix` | Explicit options (`publicHost`, `probes.gateway`, `probes.icmpTargets`); adapter in nixlab sets them. |
| S4 `probes.tcpTargets` / `tcpFromRegistry` | stack + `stacks/observability-nixlab.nix` | Rename to explicit target list; remove the registry notion from obs. |
| S5 `secretsFile` | `sops/*.nix` | Optional sops module; service options take plain secret *paths*. |
| S6 `options.nixlab.mainUser` stub | harness + 5 modules referencing `config.nixlab ? mainUser` | Replace with `extraUsers`-only; delete references. |
| S7 `runbookBase` | `rendered.nix` | Public option with a repo-derived default. |
| S8 ports | `ports.nix` | Fold defaults into modules or a documented obs port module; nixlab overrides via its own fleet module. |

---

## 10. Progress checklist (tick in commits)

- [ ] 1.1–1.6 baseline captured
- [ ] 2 publication decision recorded
- [ ] 3.1 filter-repo done and verified
- [ ] 3.3–3.6 scaffold committed
- [ ] 4.1 S3 · 4.2 S5 · 4.3 S4+S2 · 4.4 S7 committed
- [ ] 4.6–4.9 harness, host-checks, apps
- [ ] 4.10 standalone `nix flake check` green; `v0.1.0-rc1` tagged
- [ ] 5.1–5.7 nixlab integrated on branch
- [ ] 6 parity report committed
- [ ] 7.2 canary host green · 7.3 rollout · soak
- [ ] 5.8 input pinned to `v0.1.0`
- [ ] 8 close-out · seam register filled

---

## Appendix A — Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `attribute 'nixlab' missing` | The `config.nixlab ? mainUser` pattern (S6). In the harness, ensure the stub `options.nixlab.mainUser` is present. |
| `attribute 'serviceRegistry' missing` / `'hostsMeta' missing` | A leftover `self.lib.*` reference in the stack. `git grep 'self\.lib' stacks modules sops`. |
| `The option 'services.X' is defined multiple times` / duplicate option errors in nixlab | The same module name defined both by the re-export and a leftover local file (§5.2 note). `git rm` the old one. |
| `attribute 'servc--…' missing` from `self.nixosModules` inside a moved module | `self` there is the obs flake; the module you referenced isn't obs-owned (should have stayed in nixlab, or needs a seam). |
| sops: `No key source configured` / `… not in the Nix store` at eval | Harness missing `sops.age.keyFile` / `validateSopsFiles = false`. |
| New files "not found" by `nix` | Untracked in git; `git add` them (applies to both repos with `git+file` inputs). |
| `follows` warning "non-existent input" | You set `follows` for an input the obs flake doesn't declare; remove that line. |
| Parity diff shows `ExecStart` hash change but identical text | Normal; compare normalised (§6.1). |
| Host auto-upgrade fails to fetch the input | Private repo without `access-tokens`; or tag not pushed (§7.1). |

## Appendix B — Findings queued for Guides 2 and 3

Observed while reading your files; **not** acted on in Guide 1, but recorded so they aren't lost.

**For Guide 2 (decoupling) — places where the design document's boundary rules are not yet true in the code:**

1. **Loki owns Alloy's options.** `services.loki-nixlab.{enableAlloy, alloyPort, alloyPackage}` exist, `systm--ports-loki` sets `alloyPort`, and the stack reads them to configure `services.alloy-nixlab`. Design §3.1/§12.1 say Loki must not know about Alloy. Move these to `services.alloy-nixlab` and have the stack wire Loki→Alloy.
2. **Duplicate `maintenance.logPath`.** It is declared in both `loki-nixlab.maintenance` and `maintenance-log-nixlab`, with the stack syncing them. One owner needed.
3. **The stack hard-requires sops-nix.** `sops.secrets.ALERTMANAGER_ENV.restartUnits = mkIf …` assigns into `sops.secrets` unconditionally, so the option must exist even when `ntfyAuth` is off. Guarding this is required for the design's "optional sops" goal.
4. **CI reads an upstream option path** (`services.prometheus.alertmanager.configuration`) because Alertmanager uses the upstream NixOS module (DynamicUser). Hard-coded `/var/lib/private/alertmanager` in the backup list is the same coupling; document or abstract.
5. **`services.nginx.enable` / `networking.firewall` are set from five service modules** when `domain` is set — a consumer-visible side effect to document in the public contract.
6. **Port defaults are triplicated** (option default, `ports.nix`, stack reading resolved values). Pick one owner per port.

**For Guide 3 (evolution):**

7. Flatten layout (design §5) and rename namespaces with `lib.mkRenamedOptionModule` aliases for one release cycle.
8. Loki-ruler alerts (`JournalOOMKill`, `KernelFilesystemError`, `NvidiaXid`, `SSHAuthFailureBurst`) have no unit tests or runbook coverage; `_todo.txt` is a standing exception list.
9. Scripts depend on the host `PATH`; package with `writeShellApplication` + `runtimeInputs`.
10. `docs/wiki/observability.md` (very large) should be split per design §19, with LAN data removed.
11. Scrub the nixlab-specific *content* still in the product: ZFS dashboard defaults, NVIDIA Xid rule, host table in docs.
12. Add Loki/Alloy config validation to CI (only Prometheus and Alertmanager are validated today).

## Appendix C — Where this guide differs from the design document

| Design document | This guide | Why |
|---|---|---|
| Phase 4 replaces `nixlabLib`, `mainUser` etc. while moving modules | Deferred to Guide 2; guarded by an explicit seam register | Preserves behaviour/parity; keeps "move" and "refactor" separate. |
| Flatten `modules/nixos/<svc>/` in the new repo | Identical layout until Guide 3 | Quiet parity diffs, `--follow` history. |
| Rename modules/options | Deferred | Zero-edit host files. |
| "Do not pass `self`/special args" | The harness passes only `nixlabLib`, `hostMeta`, `allHosts` — and deliberately **withholds** `self`/`inputs` | Withholding `self` is a regression test for the S3 bug the design doc doesn't mention. |
| CI "moves with the repo" | Moves, **plus** exports `observabilityHostChecks` so nixlab can run the same checks on real hosts | Avoids duplicating check code; keeps real-host validation. |
| Pin a release/tag | Same, but flags that your auto-update modules make this **mandatory**, not advisory | §7.1. |
| `follows` policy "document it" | Notes it has little runtime effect here, because hosts use their own `pkgs` | Avoids false assurance. |
