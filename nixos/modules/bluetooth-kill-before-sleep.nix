{
  lib,
  config,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.bluetooth-kill-before-sleep;
in
{
  options = {
    services.bluetooth-kill-before-sleep = {
      enable = mkEnableOption "Bluetooth kill before any kind of sleep";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.bluetooth-kill-before-sleep = {
      description = "Bluetooth kill before any kind of sleep";

      before = [
        "sleep.target"
        "suspend.target"
        "hybrid-sleep.target"
        "suspend-then-hibernate.target"
      ];
      wantedBy = [
        "sleep.target"
        "suspend.target"
        "hybrid-sleep.target"
        "suspend-then-hibernate.target"
      ];

      unitConfig.StopWhenUnneeded = true;

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bluez}/bin/bluetoothctl power off";
        ExecStop = "${pkgs.bluez}/bin/bluetoothctl power on";
      };
    };
  };
}
