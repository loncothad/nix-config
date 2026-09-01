{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.convertx;
in
{
  options.services.convertx = {
    enable = lib.mkEnableOption "ConvertX file converter (https://github.com/C4illin/ConvertX)";
    package = lib.mkPackageOption pkgs "convertx" { };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Port on which ConvertX listens.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/agenix/convertx.env";
      description = "Optional environment file containing JWT_SECRET and other secrets.";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional non-secret environment variables.";
    };

    openFirewall = lib.mkEnableOption "the ConvertX port in the firewall";
  };

  config = lib.mkIf cfg.enable {
    users.users.convertx = {
      isSystemUser = true;
      group = "convertx";
    };
    users.groups.convertx = { };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    systemd.services.convertx = {
      description = "ConvertX file converter";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      environment = {
        PORT = toString cfg.port;
      }
      // cfg.environment;
      serviceConfig = {
        ExecStart = lib.getExe cfg.package;
        EnvironmentFile = lib.optional (cfg.environmentFile != null) cfg.environmentFile;
        User = "convertx";
        Group = "convertx";
        StateDirectory = "convertx";
        WorkingDirectory = "/var/lib/convertx";
        Restart = "on-failure";
        RestartSec = 5;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ "/var/lib/convertx" ];
      };
    };
  };
}
