{
  osConfig ? null,
  pkgs,
  lib,
  ...
}:

let
  hostname = if osConfig != null then osConfig.networking.hostName else "generic";
  hostKdlPath = ./by-hostname + "/${hostname}.kdl";
  hasHostConfig = builtins.pathExists hostKdlPath;
in
{
  services.xwayland-satellite = {
    enable = true;
    display = ":12";
  };

  home.packages = with pkgs; [
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
    text = lib.optionalString hasHostConfig (builtins.readFile hostKdlPath);
  };
}
