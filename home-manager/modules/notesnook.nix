{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.notesnook;
in
{
  options.programs.notesnook = {
    enable = lib.mkEnableOption "Notesnook, a private notes application (documentation: https://help.notesnook.com; source: https://github.com/streetwriters/notesnook)";

    package = lib.mkPackageOption pkgs "notesnook" { };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
  };
}
