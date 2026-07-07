{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.preferences.plymouth;
in
{
  options = {
    preferences.plymouth = {
      enable = lib.mkEnableOption "Plymouth boot splash screen";

      theme = lib.mkOption {
        type = lib.types.str;
        default = "breeze";
        description = "The literal string identifier of the target theme.";
      };

      themePack = lib.mkOption {
        type = lib.types.enum [
          "breeze"
          "adi1090x"
          "custom"
        ];
        default = "breeze";
        description = "The upstream package cluster providing the theme directory layout.";
      };

      customThemePackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "Explicit package wrappers required if themePack evaluates to 'custom'.";
      };

      logo = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to an image asset to act as the primary distribution/system logo.";
      };

      font = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to a TrueType font (.ttf) file for runtime console text routing.";
      };

      gpuDriver = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.enum [
            "amd"
            "intel"
            "intel-xe"
            "nvidia"
          ]
        );
        default = null;
        description = "GPU driver for initrd early Kernel Mode Setting (KMS).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    boot.plymouth = {
      enable = true;
      theme = cfg.theme;
      themePackages =
        if cfg.themePack == "breeze" then
          [ pkgs.kdePackages.plymouth-kcm ]
        else if cfg.themePack == "adi1090x" then
          [
            # Evaluates only the chosen theme to minimize system closure footprints
            (pkgs.adi1090x-plymouth-themes.override { selected_themes = [ cfg.theme ]; })
          ]
        else
          cfg.customThemePackages;
    }
    // lib.optionalAttrs (cfg.logo != null) { inherit (cfg) logo; }
    // lib.optionalAttrs (cfg.font != null) { inherit (cfg) font; };

    boot.kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ]
    ++ lib.optionals (cfg.gpuDriver == "nvidia") [ "nvidia-drm.modeset=1" ];

    boot.initrd.kernelModules =
      lib.optionals (cfg.gpuDriver == "amd") [ "amdgpu" ]
      ++ lib.optionals (cfg.gpuDriver == "intel") [ "i915" ]
      ++ lib.optionals (cfg.gpuDriver == "intel-xe") [ "xe" ]
      ++ lib.optionals (cfg.gpuDriver == "nvidia") [
        "nvidia"
        "nvidia_modeset"
        "nvidia_uvm"
        "nvidia_drm"
      ];
  };
}
