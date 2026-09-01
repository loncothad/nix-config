{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.rauthy;
in
{
  options.services.rauthy = {
    enable = lib.mkEnableOption "Rauthy identity provider (documentation: https://sebadob.github.io/rauthy/config/config.html)";
    package = lib.mkPackageOption pkgs "rauthy" { };

    environmentFile = lib.mkOption {
      type = lib.types.path;
      example = "/run/agenix/rauthy.env";
      description = "Environment file containing Rauthy configuration and secrets.";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Non-secret environment variables passed to Rauthy.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "rauthy";
      description = "User account under which Rauthy runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "rauthy";
      description = "Group under which Rauthy runs.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${cfg.user} = {
      isSystemUser = true;
      inherit (cfg) group;
    };
    users.groups.${cfg.group} = { };

    systemd.services.rauthy = {
      description = "Rauthy identity provider";
      documentation = [
        "https://sebadob.github.io/rauthy/config/config.html"
        "https://github.com/sebadob/rauthy"
      ];
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      environment = {
        HQL_DATA_DIR = "/var/lib/rauthy";
      }
      // cfg.environment;
      serviceConfig = {
        ExecStart = lib.getExe cfg.package;
        EnvironmentFile = cfg.environmentFile;
        User = cfg.user;
        Group = cfg.group;
        StateDirectory = "rauthy";
        WorkingDirectory = "/var/lib/rauthy";
        Restart = "on-failure";
        RestartSec = 5;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ "/var/lib/rauthy" ];
      };
    };
  };
}
