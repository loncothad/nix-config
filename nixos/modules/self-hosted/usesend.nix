{
  config,
  lib,
  ...
}:

let
  cfg = config.services.usesend;
  runtime = config.services.selfhosted.containers;
  updateLabels = lib.optionalAttrs runtime.autoUpdate.enable {
    "io.containers.autoupdate" = "registry";
  };
  containerNames = [
    "usesend-postgres"
    "usesend-redis"
    "usesend-minio"
    "usesend"
  ];
in
{
  options.services.usesend = {
    enable = lib.mkEnableOption "useSend email platform";

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/usesend/usesend:latest";
      description = "OCI image used for useSend.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host address on which useSend is published.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Host port on which useSend is published.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.path;
      example = "/run/agenix/usesend.env";
      description = ''
        Secret environment file shared by the app and its PostgreSQL, Redis,
        and MinIO dependencies. See README.md for required variables.
      '';
    };

    openFirewall = lib.mkEnableOption "the useSend port in the firewall";
  };

  config = lib.mkIf cfg.enable {
    services.selfhosted.containers.enable = true;
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    virtualisation.oci-containers.containers = {
      usesend-postgres = {
        image = "docker.io/library/postgres:16";
        networks = [ "selfhosted" ];
        environmentFiles = [ cfg.environmentFile ];
        volumes = [ "usesend-postgres:/var/lib/postgresql/data" ];
        labels = updateLabels;
      };

      usesend-redis = {
        image = "docker.io/library/redis:7";
        networks = [ "selfhosted" ];
        volumes = [ "usesend-redis:/data" ];
        cmd = [
          "redis-server"
          "--maxmemory-policy"
          "noeviction"
        ];
        labels = updateLabels;
      };

      usesend-minio = {
        image = "docker.io/minio/minio:latest";
        networks = [ "selfhosted" ];
        environmentFiles = [ cfg.environmentFile ];
        volumes = [ "usesend-minio:/data" ];
        cmd = [
          "server"
          "/data"
          "--console-address"
          ":9001"
          "--address"
          ":9002"
        ];
        labels = updateLabels;
      };

      usesend = {
        image = cfg.image;
        ports = [ "${cfg.host}:${toString cfg.port}:${toString cfg.port}" ];
        networks = [ "selfhosted" ];
        dependsOn = [
          "usesend-postgres"
          "usesend-redis"
          "usesend-minio"
        ];
        environmentFiles = [ cfg.environmentFile ];
        environment = {
          PORT = toString cfg.port;
          NEXT_PUBLIC_IS_CLOUD = "false";
        };
        labels = updateLabels;
      };
    };

    systemd.services = lib.genAttrs (map (name: "podman-${name}") containerNames) (_: {
      after = [ "selfhosted-podman-network.service" ];
      requires = [ "selfhosted-podman-network.service" ];
    });
  };
}
