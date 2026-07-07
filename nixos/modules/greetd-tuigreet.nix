{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.greetd.tuigreet;
  tomlFormat = pkgs.formats.toml { };
in
{
  options = {
    services.greetd.tuigreet = {
      enable = mkEnableOption "tuigreet, a modern graphical console greeter for greetd";

      package = mkOption {
        type = types.package;
        description = "The tuigreet package to execute. Pass your flake input or overridden derivation here.";
      };

      settings = mkOption {
        type = tomlFormat.type;
        default = { };
        description = ''
          Declarative TOML configuration for tuigreet, generated at /etc/tuigreet/config.toml.
          Command priority ensures CLI args override these properties.
        '';
        example = literalExpression ''
          {
            display = {
              show_time = true;
              greeting = "Welcome to NixOS";
              align_greeting = "center";
            };
            layout = {
              width = 80;
              window_padding = 2;
            };
            remember = {
              username = true;
              session = true;
              user_session = true;
            };
            session = {
              sessions_dirs = [
                "/run/current-system/sw/share/wayland-sessions"
                "/run/current-system/sw/share/xsessions"
              ];
            };
          }
        '';
      };

      extraArgs = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Extra command line flags to append to the tuigreet invocation.";
        example = [
          "--time"
          "--theme"
          "border=magenta;text=cyan"
        ];
      };
    };
  };

  config = mkIf cfg.enable {
    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${cfg.package}/bin/tuigreet --config /etc/tuigreet/config.toml ${escapeShellArgs cfg.extraArgs}";
          user = "greeter";
        };
      };
    };

    environment.etc."tuigreet/config.toml".source =
      tomlFormat.generate "tuigreet-config.toml" cfg.settings;

    systemd.tmpfiles.rules = [
      "d /var/cache/tuigreet 0755 greeter greeter - -"
    ];
  };
}
