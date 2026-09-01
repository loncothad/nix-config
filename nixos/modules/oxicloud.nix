{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.oxicloud;
in
{
  options.services.oxicloud = {
    enable = lib.mkEnableOption "OxiCloud file server (documentation: https://github.com/AtalayaLabs/OxiCloud#readme)";
    package = lib.mkPackageOption pkgs "oxicloud" { };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address on which OxiCloud listens.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8086;
      description = "Port on which OxiCloud listens.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.path;
      example = "/run/agenix/oxicloud.env";
      description = "Environment file containing the database URL and other secrets.";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional non-secret environment variables.";
    };

    openFirewall = lib.mkEnableOption "the OxiCloud port in the firewall";
  };

  config = lib.mkIf cfg.enable {
    users.users.oxicloud = {
      isSystemUser = true;
      group = "oxicloud";
    };
    users.groups.oxicloud = { };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    systemd.services.oxicloud = {
      description = "OxiCloud file server";
      documentation = [ "https://github.com/AtalayaLabs/OxiCloud#readme" ];
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      environment = {
        OXICLOUD_SERVER_HOST = cfg.host;
        OXICLOUD_SERVER_PORT = toString cfg.port;
        OXICLOUD_STORAGE_PATH = "/var/lib/oxicloud/storage";
        MIMALLOC_PURGE_DELAY = "0";
      }
      // cfg.environment;
      serviceConfig = {
        ExecStart = lib.getExe cfg.package;
        EnvironmentFile = cfg.environmentFile;
        User = "oxicloud";
        Group = "oxicloud";
        StateDirectory = "oxicloud";
        WorkingDirectory = "/var/lib/oxicloud";
        Restart = "on-failure";
        RestartSec = 5;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ "/var/lib/oxicloud" ];
      };
    };
  };
}
