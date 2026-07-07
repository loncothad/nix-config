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

      disableBashCompletion = mkOption {
        type = types.bool;
        default = false;
        description = "Disable system-wide Bash completion loading to speed up shell initialization.";
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.disableMan {
      programs.man.enable = false;
      programs.man.man-db.enable = false;
      manual.manpages.enable = false;
    })

    (mkIf cfg.disableBashCompletion {
      programs.bash.enableCompletion = false;
    })
  ];
}
