{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.gtk;
in
{
  options = {
    gtk = {
      preferDarkTheme = mkEnableOption "GTK prefer dark theme";
    };
  };

  config = mkIf cfg.preferDarkTheme {
    gtk2.extraConfig = "gtk-application-prefer-dark-theme = true";
    gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
  };
}
