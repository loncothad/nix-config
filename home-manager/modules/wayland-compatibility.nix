{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.wayland-compatibility;
in
{
  options = {
    wayland-compatibility = {
      enable = mkEnableOption "Common environment variables and fixes for Wayland compatibility";
    };
  };

  config = mkIf cfg.enable {
    home.sessionVariables = {
      LIBSEAT_BACKEND = "logind";

      XDG_SESSION_TYPE = "wayland";

      NIXOS_OZONE_WL = "1";

      GDK_BACKEND = "wayland,x11";
      SDL_VIDEODRIVER = "wayland,x11";
      CLUTTER_BACKEND = "wayland";
      ECORE_EVAS_ENGINE = "wayland_egl";
      ELM_ENGINE = "wayland_egl";

      QT_QPA_PLATFORM = "wayland;xcb";
      QT_AUTO_SCREEN_SCALE_FACTOR = "1";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      QT_WAYLAND_FORCE_DPI = "physical";

      MOZ_ENABLE_WAYLAND = "1";
      MOZ_DBUS_REMOTE = "1";
      MOZ_USE_XINPUT2 = "1";

      WINIT_UNIX_BACKEND = "wayland";

      _JAVA_AWT_WM_NONREPARENTING = "1";
      # _JAVA_OPTIONS = "-Dawt.useSystemAAFontSettings=on -Dswing.aatext=true -Dsun.java2d.xrender=true";

      # fixme: do we need these all?
    };

    home.packages = with pkgs; [
      kdePackages.qtwayland # For Qt6 apps
      libsForQt5.qt5.qtwayland # For Qt5 apps

      wl-clipboard
      wl-clipboard-x11
      wayland-utils
    ];
  };
}
