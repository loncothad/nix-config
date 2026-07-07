{ config, lib, ... }:

with lib;

let
  cfg = config.debloat;
in
{
  options = {
    debloat = {
      disableMan = mkOption {
        type = types.bool;
        default = false;
        description = "Fully disable man pages, info pages, and all core documentation.";
      };

      disableX11Defaults = mkOption {
        type = types.bool;
        default = false;
        description = "Disable stock X11 packages (like xterm) from the default X server config.";
      };

      disableSudo = mkOption {
        type = types.bool;
        default = false;
        description = "Disable sudo completely. Ensure an alternative or root password exists.";
      };

      disableDefaultPackages = mkOption {
        type = types.bool;
        default = false;
        description = "Clear the environment.defaultPackages list (nano, perl, rsync, etc.).";
      };

      disableCommandNotFound = mkOption {
        type = types.bool;
        default = false;
        description = "Disable the command-not-found tool and database channel lookups.";
      };

      disableNixChannels = mkOption {
        type = types.bool;
        default = false;
        description = "Disable legacy Nix channel commands and infrastructure (ideal for pure Flake setups).";
      };

      disableBashCompletion = mkOption {
        type = types.bool;
        default = false;
        description = "Disable system-wide Bash completion loading to speed up shell initialization.";
      };

      disableGettyHelp = mkOption {
        type = types.bool;
        default = false;
        description = "Disable the default login hint text on virtual consoles.";
      };

      disableFirmware = mkOption {
        type = types.bool;
        default = false;
        description = "Disable loading redistributable firmware blobs (useful for cloud VMs and containers).";
      };

      disableEmergencyMode = mkOption {
        type = types.bool;
        default = false;
        description = "Disable systemd emergency/rescue shell mode to strip single-user entrypoint utilities.";
      };

      disableStorageDaemons = mkOption {
        type = types.bool;
        default = false;
        description = "Disable software RAID (mdadm) and iSCSI monitoring utilities from initrd and runtime hooks.";
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.disableMan {
      documentation.enable = false;
      documentation.man.enable = false;
      documentation.doc.enable = false;
      documentation.info.enable = false;
      documentation.dev.enable = false;
      documentation.nixos.enable = false;
    })

    (mkIf cfg.disableX11Defaults {
      services.xserver.desktopManager.xterm.enable = false;
      services.xserver.excludePackages = [ pkgs.xterm ];
    })

    (mkIf cfg.disableSudo {
      security.sudo.enable = false;
    })

    (mkIf cfg.disableDefaultPackages {
      environment.defaultPackages = lib.mkForce [ ];
    })

    (mkIf cfg.disableCommandNotFound {
      programs.command-not-found.enable = false;
    })

    (mkIf cfg.disableNixChannels {
      nix.channel.enable = false;
    })

    (mkIf cfg.disableBashCompletion {
      programs.bash.completion.enable = false;
    })

    (mkIf cfg.disableGettyHelp {
      services.getty.helpLine = lib.mkForce "";
    })

    (mkIf cfg.disableFirmware {
      hardware.enableRedistributableFirmware = lib.mkForce false;
      hardware.firmware = lib.mkForce [ ];
    })

    (mkIf cfg.disableEmergencyMode {
      systemd.enableEmergencyMode = false;
    })

    (mkIf cfg.disableStorageDaemons {
      boot.swraid.enable = false;
      boot.iscsi.enable = false;
    })
  ];
}
