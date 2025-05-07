{ pkgs, ... }:
let
  BackupHomeShellScript = pkgs.writeShellScript "auto-backup-home" ( builtins.readFile ../../../scripts/auto-backup-home.sh );
in
{
  systemd.services.backup-home = {
    description = "Nightly Home directory backup";
    serviceConfig = {
      ExecStart = BackupHomeShellScript;
      Type = "oneshot";
      User = "root";
    };
    path = [ pkgs.rsync "/root"];
    startAt = "03:30:00";
  };
}
