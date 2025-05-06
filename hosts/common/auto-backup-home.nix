{ config, lib, pkgs, ... }:
let
  backuphomeShellScript = pkgs.writeShellScript "auto-backup-home" ( builtins.readFile ../../scripts/auto-backup-home.sh );
in
{

  systemd.services.backup-home = {
    description = "script write";
    serviceConfig = {
      ExecStart = backuphomeShellScript;
      Type = "oneshot";
      User = "root";
    };
    path = [ pkgs.rsync "/root"];
    startAt = "03:30:00";
  };
}
