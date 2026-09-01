{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.xdg-dbus-proxy;

  proxyType = types.submodule (
    { name, ... }:
    {
      options = {
        address = mkOption {
          type = types.str;
          default = "unix:path=%t/bus";
          description = "D-Bus address to proxy.";
        };

        socket = mkOption {
          type = types.str;
          default = "%t/xdg-dbus-proxy/${name}.sock";
          description = "Unix socket on which the proxy listens.";
        };

        filter = mkEnableOption "D-Bus message filtering" // {
          default = true;
        };

        log = mkEnableOption "proxy message logging";
        sloppyNames = mkEnableOption "visibility of all unique D-Bus names";

        see = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Well-known D-Bus names the client may see.";
        };

        talk = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Well-known D-Bus names the client may talk to.";
        };

        own = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Well-known D-Bus names the client may own.";
        };

        calls = mkOption {
          type = types.attrsOf (types.listOf types.str);
          default = { };
          example = {
            "org.freedesktop.portal.*" = [ "*" ];
          };
          description = "Allowed call rules, keyed by well-known D-Bus name.";
        };

        broadcasts = mkOption {
          type = types.attrsOf (types.listOf types.str);
          default = { };
          example = {
            "org.freedesktop.portal.*" = [ "@/org/freedesktop/portal/*" ];
          };
          description = "Allowed broadcast rules, keyed by well-known D-Bus name.";
        };

        extraArgs = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Extra command-line arguments for this proxy.";
        };
      };
    }
  );

  ruleArgs =
    option: rules:
    concatLists (
      mapAttrsToList (name: values: map (value: "--${option}=${name}=${value}") values) rules
    );

  proxyArgs =
    proxy:
    [
      proxy.address
      proxy.socket
    ]
    ++ optional proxy.filter "--filter"
    ++ optional proxy.log "--log"
    ++ optional proxy.sloppyNames "--sloppy-names"
    ++ map (name: "--see=${name}") proxy.see
    ++ map (name: "--talk=${name}") proxy.talk
    ++ map (name: "--own=${name}") proxy.own
    ++ ruleArgs "call" proxy.calls
    ++ ruleArgs "broadcast" proxy.broadcasts
    ++ proxy.extraArgs;

  mkService =
    name: proxy:
    nameValuePair "xdg-dbus-proxy-${name}" {
      Unit = {
        Description = "D-Bus proxy ${name}";
        Documentation = [ "https://github.com/flatpak/xdg-dbus-proxy#readme" ];
        After = [ "dbus.service" ];
      };

      Service = {
        ExecStartPre = escapeShellArgs [
          "${pkgs.coreutils}/bin/mkdir"
          "-p"
          (builtins.dirOf proxy.socket)
        ];
        ExecStart = escapeShellArgs ([ (getExe cfg.package) ] ++ proxyArgs proxy);
        Restart = "on-failure";
        RestartSec = 3;
      };

      Install.WantedBy = [ "default.target" ];
    };
in
{
  options.services.xdg-dbus-proxy = {
    enable = mkEnableOption "filtered user D-Bus proxies (documentation: https://github.com/flatpak/xdg-dbus-proxy#readme)";

    package = mkPackageOption pkgs "xdg-dbus-proxy" { };

    proxies = mkOption {
      type = types.attrsOf proxyType;
      default = { };
      example = literalExpression ''
        {
          sandbox = {
            talk = [ "org.freedesktop.portal.*" ];
            own = [ "com.example.Sandbox" ];
          };
        }
      '';
      description = "Named D-Bus proxy instances managed as systemd user services.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.proxies != { };
        message = "services.xdg-dbus-proxy.proxies must define at least one proxy.";
      }
      {
        assertion = all (name: match "^[A-Za-z0-9_.@-]+$" name != null) (attrNames cfg.proxies);
        message = "services.xdg-dbus-proxy proxy names may contain only letters, digits, dot, underscore, @, and hyphen.";
      }
      {
        assertion =
          let
            sockets = mapAttrsToList (_: proxy: proxy.socket) cfg.proxies;
          in
          length sockets == length (unique sockets);
        message = "services.xdg-dbus-proxy proxy socket paths must be unique.";
      }
    ];

    home.packages = [ cfg.package ];
    systemd.user.services = mapAttrs' mkService cfg.proxies;
  };
}
