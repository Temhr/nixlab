{...}: {
  flake.nixosModules.nsops--alertmanager = {
    config,
    lib,
    self,
    ...
  }: let
    cfg = config.services.alertmanager-nixlab;
  in {
    imports = [self.nixosModules.servc--alertmanager-nixlab];
    options.services.alertmanager-nixlab.secretsFile = lib.mkOption {
      type = lib.types.path;
      default = ./alertmanager.yaml;
      defaultText = lib.literalExpression "./alertmanager.yaml";
      description = ''
        Path to the sops-encrypted alertmanager secrets file.
        Defaults to alertmanager.yaml co-located with this module.
        Override per-host if needed.

        The decrypted file is rendered as KEY=VALUE pairs and injected
        into the Alertmanager process environment at startup. Reference
        the keys as $KEY inside receiver configs to keep secrets out of
        the Nix store.

        Example file contents (before sops encryption):
          SLACK_WEBHOOK_URL=https://hooks.slack.com/services/T.../B.../xxx
          SLACK_WEBHOOK_URL_CRITICAL=https://hooks.slack.com/services/T.../B.../yyy
          PAGERDUTY_ROUTING_KEY=abc123
          SMTP_PASSWORD=hunter2
          NTFY_PASSWORD=supersecret
      '';
    };

    config = lib.mkIf cfg.enable {
      sops.secrets.ALERTMANAGER_ENV = {
        sopsFile = cfg.secretsFile;
        # The upstream NixOS alertmanager module uses DynamicUser, so there is
        # no persistent system user to own the file. We leave owner as root and
        # rely on EnvironmentFiles= being read by systemd (as root) before the
        # process drops privileges — the same approach used by other DynamicUser
        # services in nixpkgs.
        format = "dotenv";
        restartUnits = ["alertmanager.service"];
      };

      # Wire the decrypted file path into the service module option so the
      # EnvironmentFiles= directive picks it up automatically.
      services.alertmanager-nixlab.environmentFile =
        config.sops.secrets.ALERTMANAGER_ENV.path;

      # amtool cannot see the decrypted secrets file inside the Nix build
      # sandbox, so disable build-time config validation automatically when
      # this sops module is imported. The operator can re-enable it on hosts
      # that have no secret references in their receiver configs.
      services.alertmanager-nixlab.checkConfig = lib.mkDefault false;
    };
  };
}
