{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.selfhosted.autoUpdate;
in
{
  options.services.selfhosted.autoUpdate = {
    enable = lib.mkEnableOption "automatic updates for native self-hosted packages";

    flake = lib.mkOption {
      type = lib.types.str;
      example = "github:loncothad/nix-config";
      description = ''
        Flake URI used for unattended NixOS upgrades. Use a remote, clean flake
        reference; a mutable local working tree is not suitable for a timer.
      '';
    };

    dates = lib.mkOption {
      type = lib.types.str;
      default = "04:00";
      description = "systemd calendar expression for checking for NixOS updates.";
    };

    randomizedDelaySec = lib.mkOption {
      type = lib.types.str;
      default = "45min";
      description = "Random delay applied to each automatic upgrade run.";
    };
  };

  config = lib.mkIf cfg.enable {
    system.autoUpgrade = {
      enable = true;
      inherit (cfg) dates flake randomizedDelaySec;
      operation = "boot";
      allowReboot = false;
    };

    systemd.services.nixos-upgrade.path = [ pkgs.gitMinimal ];
  };
}
