{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.ferron;
  configFile = pkgs.writeText "ferron.kdl" cfg.config;
in
{
  options.services.ferron = {
    enable = lib.mkEnableOption "Ferron web server (https://github.com/ferronweb/ferron)";

    package = lib.mkPackageOption pkgs "ferron" { };

    config = lib.mkOption {
      type = lib.types.lines;
      example = ''
        globals {
          log_stdout
          error_log_stderr
        }

        :8080 {
          root "/srv/www"
        }
      '';
      description = ''
        Ferron KDL configuration. Use environment placeholders with
        environmentFiles for values that must not enter the Nix store.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "ferron";
      description = "User account under which Ferron runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "ferron";
      description = "Group under which Ferron runs.";
    };

    supplementaryGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "php-fpm" ];
      description = "Additional groups granted to Ferron, such as a PHP-FPM socket group.";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Non-secret environment variables passed to Ferron.";
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "/run/agenix/ferron.env" ];
      description = "Runtime environment files containing Ferron configuration values and secrets.";
    };

    writablePaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "/srv/www/uploads" ];
      description = "Additional paths Ferron may write despite systemd filesystem protection.";
    };

    firewall.allowedTCPPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ ];
      example = [
        80
        443
      ];
      description = "TCP ports to open in the firewall for Ferron.";
    };

    firewall.allowedUDPPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ ];
      example = [ 443 ];
      description = "UDP ports to open in the firewall for Ferron, for example for HTTP/3.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc."ferron.kdl".source = configFile;

    users.users = lib.optionalAttrs (cfg.user == "ferron") {
      ferron = {
        isSystemUser = true;
        inherit (cfg) group;
        home = "/var/lib/ferron";
      };
    };
    users.groups = lib.optionalAttrs (cfg.group == "ferron") {
      ferron = { };
    };

    networking.firewall = {
      inherit (cfg.firewall) allowedTCPPorts allowedUDPPorts;
    };

    systemd.services.ferron = {
      description = "Ferron web server";
      documentation = [ "https://ferron.sh/docs" ];
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      reloadTriggers = [ configFile ];
      environment = {
        HOME = "/var/lib/ferron";
        XDG_CACHE_HOME = "/var/cache/ferron";
        XDG_DATA_HOME = "/var/lib/ferron";
      }
      // cfg.environment;
      serviceConfig = {
        Type = "simple";
        ExecStart = "${lib.getExe cfg.package} --config /etc/ferron.kdl";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
        User = cfg.user;
        Group = cfg.group;
        SupplementaryGroups = cfg.supplementaryGroups;
        EnvironmentFile = cfg.environmentFiles;
        StateDirectory = "ferron";
        CacheDirectory = "ferron";
        LogsDirectory = "ferron";
        WorkingDirectory = "/var/lib/ferron";
        Restart = "on-failure";
        RestartSec = 5;
        UMask = "0027";

        AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
        CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [
          "/var/cache/ferron"
          "/var/lib/ferron"
          "/var/log/ferron"
        ]
        ++ cfg.writablePaths;
      };
    };
  };
}
