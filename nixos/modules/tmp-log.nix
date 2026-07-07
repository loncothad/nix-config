{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.fileSystems.tmp-log;
in
{
  options = {
    fileSystems.tmp-log = {
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
