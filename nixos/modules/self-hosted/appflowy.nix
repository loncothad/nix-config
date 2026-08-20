{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.appflowy;
in
{
  options.programs.appflowy = {
    enable = lib.mkEnableOption "the AppFlowy desktop client";
    package = lib.mkPackageOption pkgs "appflowy" { };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
