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
    enable = lib.mkEnableOption "Fastpotify, a native Spotify client";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.fromFlakes.fastpotify.fastpotify;
      defaultText = lib.literalExpression "pkgs.fromFlakes.fastpotify.fastpotify";
      description = "The Fastpotify package to install.";
    };

    settings = lib.mkOption {
      type = jsonFormat.type;
      default = { };
      description = ''
        Settings written to {file}`$XDG_CONFIG_HOME/fastpotify/settings.json`.
        See Fastpotify's upstream documentation for supported keys.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.configFile."fastpotify/settings.json" = lib.mkIf (cfg.settings != { }) {
      source = jsonFormat.generate "fastpotify-settings.json" cfg.settings;
    };
  };
}
