{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.xwayland-satellite;
in
{
  options.services.xwayland-satellite = {
    enable = mkEnableOption "xwayland-satellite, Xwayland outside your Wayland compositor";

    package = mkPackageOption pkgs "xwayland-satellite" { };

    display = mkOption {
      type = types.str;
      default = ":12";
      example = ":0";
      description = "X11 display the satellite should own (passed as the first argument).";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    home.sessionVariables.DISPLAY = cfg.display;

    systemd.user.services.xwayland-satellite = {
      Unit = {
        Description = "Xwayland outside your Wayland compositor";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${getExe cfg.package} ${cfg.display}";
        Restart = "on-failure";
        RestartSec = 3;
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
