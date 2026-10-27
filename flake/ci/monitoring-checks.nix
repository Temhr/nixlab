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
