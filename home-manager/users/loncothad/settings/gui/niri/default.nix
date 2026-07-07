{
  config,
  osConfig ? null,
  pkgs,
  lib,
  ...
}:

let
  hostname = if osConfig != null then osConfig.networking.hostName else "generic";
  hostKdlPath = ./by-hostname + "/${hostname}.kdl";
  hasHostConfig = builtins.pathExists hostKdlPath;

  hasAshell = config.programs.ashell.enable or false;
  hasQuickshell = config.programs.quickshell.enable or false;
  hasHyprpaper = config.services.hyprpaper.enable or false;
in
{
  home.packages = with pkgs; [
    xwayland-satellite
    wl-clipboard
    wl-clipboard-x11
  ];

  xdg.portal.config.niri = {
    "org.freedesktop.impl.portal.FileChooser" = [ "kde" ];
  };

  xdg.configFile."niri/config.kdl" = {
    source = ./config.kdl;
  };

  xdg.configFile."niri/host-settings.kdl" = {
    text =
      lib.optionalString hasHostConfig (builtins.readFile hostKdlPath)
      + "\n"
      + ''
        // Autostart services driven by your declarative home configuration
        spawn-at-startup "xwayland-satellite" ":12"
        ${lib.optionalString hasHyprpaper "spawn-at-startup \"hyprpaper\""}
        ${lib.optionalString hasAshell "spawn-at-startup \"ashell\""}
        ${lib.optionalString hasQuickshell "spawn-at-startup \"quickshell\""}
      '';
  };
}
