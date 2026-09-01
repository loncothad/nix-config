{
  config,
  lib,
  ...
}:

let
  root = config.virtualisation.oci-containers.namedContainers;
  cfg = root.usesend;
  runtime = root;
  updateLabels = lib.optionalAttrs runtime.autoUpdate.enable {
    "io.containers.autoupdate" = "registry";
  };
  dependencyNames =
    lib.optional cfg.postgres.createLocally "usesend-postgres"
    ++ lib.optional cfg.redis.createLocally "usesend-redis"
    ++ lib.optional cfg.minio.createLocally "usesend-minio";
  containerNames = dependencyNames ++ [ "usesend" ];
in
{
  options.virtualisation.oci-containers.namedContainers.usesend = {
    enable = lib.mkEnableOption "useSend email platform (documentation: https://github.com/usesend/useSend#readme)";

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

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional non-secret environment variables for useSend.";
    };

    postgres.createLocally = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to run a dedicated PostgreSQL container. When false, configure
        the external database through environmentFile.
      '';
    };

    redis.createLocally = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to run a dedicated Redis container. When false, configure the
        external cache through environmentFile.
      '';
    };

    minio.createLocally = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to run a dedicated MinIO container. When false, configure
        reusable S3-compatible storage through environmentFile.
      '';
    };

    openFirewall = lib.mkEnableOption "the useSend port in the firewall";
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.namedContainers.enable = true;
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    virtualisation.oci-containers.containers = {
      usesend = {
        image = cfg.image;
        ports = [ "${cfg.host}:${toString cfg.port}:${toString cfg.port}" ];
        networks = [ "selfhosted" ];
        dependsOn = dependencyNames;
        environmentFiles = [ cfg.environmentFile ];
        environment = {
          PORT = toString cfg.port;
          NEXT_PUBLIC_IS_CLOUD = "false";
        }
        // cfg.environment;
        labels = updateLabels;
      };
    }
    // lib.optionalAttrs cfg.postgres.createLocally {
      usesend-postgres = {
        image = "docker.io/library/postgres:16";
        networks = [ "selfhosted" ];
        environmentFiles = [ cfg.environmentFile ];
        volumes = [ "usesend-postgres:/var/lib/postgresql/data" ];
        labels = updateLabels;
      };
    }
    // lib.optionalAttrs cfg.redis.createLocally {
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
    }
    // lib.optionalAttrs cfg.minio.createLocally {
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
    };

    systemd.services = lib.genAttrs (map (name: "podman-${name}") containerNames) (_: {
      documentation = [ "https://github.com/usesend/useSend#readme" ];
      after = [ "selfhosted-podman-network.service" ];
      requires = [ "selfhosted-podman-network.service" ];
    });
  };
}
