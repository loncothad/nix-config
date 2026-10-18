{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.fastpotify;
  jsonFormat = pkgs.formats.json { };
in
{
  options.programs.fastpotify = {
    enable = lib.mkEnableOption "Spotifast, a native Spotify client (documentation: https://spotifast.rocks)";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The Spotifast package to install.";
    };

    settings = lib.mkOption {
      type = jsonFormat.type;
      default = { };
      description = ''
        Settings written to {file}`$XDG_CONFIG_HOME/spotifast/settings.json`.
        See https://spotifast.rocks for supported keys.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.configFile."spotifast/settings.json" = lib.mkIf (cfg.settings != { }) {
      source = jsonFormat.generate "spotifast-settings.json" cfg.settings;
    };
  };
}
