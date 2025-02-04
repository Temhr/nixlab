{ config, lib, pkgs, ... }:
let
  backuphomeShellScript = pkgs.writeShellScript "backup-home" ( builtins.readFile ../../bin/backup-home.sh );
in
{

  systemd.services.backup-home = {
    description = "script write";
    serviceConfig = {
      ExecStart = "${pkgs.rsync} ${backuphomeShellScript}";
      Type = "oneshot";
      User = "root";
    };
    path = [ pkgs.rsync ];
    startAt = "03:30";
  };
}
