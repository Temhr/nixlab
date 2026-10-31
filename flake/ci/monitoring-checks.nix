# Build-time validation of the monitoring stack's generated configuration.
{
  self,
  lib,
  ...
}: {
  perSystem = {
    pkgs,
    system,
    ...
  }: let
    inherit (self.lib) prometheusRendered prometheusMaintenanceAlerts;
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

    # Hubs are on nixpkgs-stable and agents on nixpkgs-unstable (hosts-meta.nix),
    # so one of each is validated.
    perHost = host: let
      hostConfig = self.nixosConfigurations.${host}.config;
      rendered = prometheusRendered {
        config = hostConfig;
        lib = pkgs.lib;
      };
    in {
      "prom-config-${host}" = pkgs.runCommand "prom-config-${host}" {nativeBuildInputs = tools;} ''
        remarshal -i ${toJson "prometheus.json" rendered.prometheusConfig} -if json -of yaml -o prometheus.yml
        promtool check config --syntax-only prometheus.yml
        touch $out
      '';
      "prom-rules-${host}" = pkgs.runCommand "prom-rules-${host}" {nativeBuildInputs = tools;} ''
        remarshal -i ${toJson "rules.json" rendered.rules} -if json -of yaml -o rules.yml
        promtool check rules rules.yml
        touch $out
      '';
      "alertmanager-config-${host}" = pkgs.runCommand "alertmanager-config-${host}" {nativeBuildInputs = tools;} ''
        remarshal -i ${toJson "am.json" hostConfig.services.prometheus.alertmanager.configuration} -if json -of yaml -o am.yml
        for v in $(grep -o '\$[A-Z_][A-Z0-9_]*' am.yml | tr -d '$' | sort -u); do export "$v=dummy"; done
        envsubst < am.yml > am.sub.yml
        amtool check-config am.sub.yml
        touch $out
      '';
    };
  in {
    checks = lib.optionalAttrs (system == "x86_64-linux") (
      (lib.foldl' (acc: host: acc // perHost host) {} ["nixnas1" "nixsun"])
      // {
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
