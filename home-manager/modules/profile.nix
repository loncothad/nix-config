{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.profile;
in
{
  options = {
    profile = {
      desktop = {
        enable = mkEnableOption "graphical desktop environment profile";

        xkb = {
          layout = mkOption {
            type = types.str;
            default = "us";
            description = "Keyboard layout geometry (e.g., 'us', 'de').";
          };
          variant = mkOption {
            type = types.str;
            default = "";
            description = "Keyboard layout variant (e.g., 'colemak', 'dvorak').";
          };
          options = mkOption {
            type = types.listOf types.str;
            default = [ "caps:escape" ];
            description = "XKB options list (e.g., remaps, switching behavior).";
          };
        };

        mainDisplay = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "DP-1";
          description = "The designated primary/main display output interface.";
        };

        displays = mkOption {
          description = "Declarative display output styling mapped by interface name.";
          default = { };
          type = types.attrsOf (
            types.submodule {
              options = {
                resolution = mkOption {
                  description = "Target display resolution dimensions.";
                  default = {
                    width = 1920;
                    height = 1080;
                  };
                  type = types.submodule {
                    options = {
                      width = mkOption {
                        type = types.int;
                        default = 1920;
                        example = 3840;
                      };
                      height = mkOption {
                        type = types.int;
                        default = 1080;
                        example = 2160;
                      };
                    };
                  };
                };
                refreshRate = mkOption {
                  type = types.int;
                  default = 60;
                  example = 144;
                };
                position = mkOption {
                  type = types.str;
                  default = "auto";
                  example = "0x0";
                };
                scale = mkOption {
                  type = types.str;
                  default = "1";
                  example = "1.25";
                };
              };
            }
          );
        };
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.desktop.enable {
      home.keyboard = {
        layout = cfg.desktop.xkb.layout;
        variant = cfg.desktop.xkb.variant;
        options = cfg.desktop.xkb.options;
      };

      home.sessionVariables = mkIf (cfg.desktop.mainDisplay != null) {
        MAIN_DISPLAY = cfg.desktop.mainDisplay;
      };
    })
  ];
}
