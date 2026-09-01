{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.xwayland-satellite;
  command = escapeShellArgs (
    [
      (getExe cfg.package)
      cfg.display
    ]
    ++ cfg.extraArgs
  );
in
{
  options.services.xwayland-satellite = {
    enable = mkEnableOption "xwayland-satellite, Xwayland outside your Wayland compositor (documentation: https://github.com/Supreeeme/xwayland-satellite#readme)";

    package = mkPackageOption pkgs "xwayland-satellite" { };

    display = mkOption {
      type = types.str;
      default = ":12";
      example = ":0";
      description = "X11 display the satellite should own (passed as the first argument).";
    };

    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional command-line arguments passed to xwayland-satellite.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    home.sessionVariables.DISPLAY = cfg.display;

    systemd.user.services.xwayland-satellite = {
      Unit = {
        Description = "Xwayland outside your Wayland compositor";
        Documentation = [ "https://github.com/Supreeeme/xwayland-satellite#readme" ];
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = command;
        Restart = "on-failure";
        RestartSec = 3;
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
