{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.boot.tmp-log;
in
{
  options = {
    boot.tmp-log = {
      enable = mkEnableOption "tmpfs on /var/log";
    };
  };

  config = mkIf cfg.enable {
    fileSystems."/var/log" = {
      device = "none";
      fsType = "tmpfs";
      options = [
        "size=200M"
        "mode=777"
      ];
    };
  };
}
