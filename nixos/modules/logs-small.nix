{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.systemd.small-logs;
in
{
  options = {
    systemd.small-logs = {
      enable = mkEnableOption "small logs";
    };
  };

  config = mkIf cfg.enable {
    services.journald.extraConfig = "SystemMaxUse=200M";
    systemd.coredump.settings.Coredump.MaxUse = "200M";

    boot.kernelParams = [ "log_buf_len=20M" ];
  };
}
