{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.qt;
  catppuccin = pkgs.catppuccin-qt5ct;
  scheme = "catppuccin-mocha-blue";

  appearance = colorPath: {
    Appearance = {
      style = "Breeze";
      icon_theme = "Papirus-Dark";
      standard_dialogs = "xdgdesktopportal";
      custom_palette = true;
      color_scheme_path = colorPath;
    };
  };
in
{
  options = {
    qt = {
      preferDarkTheme = mkEnableOption "dark Qt theming (Breeze + Catppuccin Mocha)";
    };
  };

  config = mkIf cfg.preferDarkTheme {
    qt = {
      enable = true;
      # qtct instead of kde: Breeze widgets without pulling Plasma.
      platformTheme.name = "qtct";
      style.name = "breeze";
      qt5ctSettings = appearance "${catppuccin}/share/qt5ct/colors/${scheme}.conf";
      qt6ctSettings = appearance "${catppuccin}/share/qt6ct/colors/${scheme}.conf";
    };

    home.packages = with pkgs; [
      catppuccin-qt5ct
      papirus-icon-theme
      kdePackages.breeze-icons
    ];
  };
}
