{ config, lib, ... }:

let
  cfg = config.services.hardwareWatchdog;
in
{
  options.services.hardwareWatchdog = {
    enable = lib.mkEnableOption "systemd hardware watchdog management";

    device = lib.mkOption {
      type = lib.types.str;
      default = "/dev/watchdog0";
      description = "Path to the hardware watchdog device node.";
    };

    runtimeTimeout = lib.mkOption {
      type = lib.types.str;
      default = "5s";
      description = "Watchdog timeout during normal system runtime.";
    };

    rebootTimeout = lib.mkOption {
      type = lib.types.str;
      default = "30s";
      description = "Watchdog timeout during shutdown and reboot sequences.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.settings.Manager = {
      WatchdogDevice = cfg.device;
      RuntimeWatchdogSec = cfg.runtimeTimeout;
      RebootWatchdogSec = cfg.rebootTimeout;
    };
  };
}
