{...}: {
  flake.nixosModules.hardw--mounts--nfs-mirror-server = {config, lib, ...}: let
    cfg = config.nfsMirrorServer;
  in {
    options.nfsMirrorServer = {
      enable = lib.mkEnableOption "NFSv4 mirror export";
      exportPath = lib.mkOption {type = lib.types.str; default = "/mirror";};
      allowedNetwork = lib.mkOption {type = lib.types.str; default = "10.0.0.0/24";};
      exportOptions = lib.mkOption {
        type = lib.types.str;
        default = "ro,root_squash,fsid=0,no_subtree_check";
      };
    };
    config = lib.mkIf cfg.enable {
      services.nfs.server = {
        enable = true;
        exports = "${cfg.exportPath} ${cfg.allowedNetwork}(${cfg.exportOptions})\n";
      };
      services.nfs.settings.nfsd.vers3 = false;
      systemd.services.nfs-server.unitConfig.RequiresMountsFor = [cfg.exportPath];
      networking.firewall.allowedTCPPorts = [2049];

      # Safety net: retry if nfs-server isn't running (see section 3)
      systemd.services.nfs-server-ensure = {
        description = "Start nfs-server if it is not running";
        unitConfig.ConditionPathIsMountPoint = cfg.exportPath;
        serviceConfig.Type = "oneshot";
        script = "systemctl is-active --quiet nfs-server || systemctl start nfs-server";
      };
      systemd.timers.nfs-server-ensure = {
        wantedBy = ["timers.target"];
        timerConfig = {OnBootSec = "2min"; OnUnitActiveSec = "2min";};
      };
    };
  };
}
