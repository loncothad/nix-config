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
  ownsPostgres = cfg.postgres.mode == "owned";
  ownsRedis = cfg.redis.mode == "owned";
  ownsMinio = cfg.minio.mode == "owned";
  dependencyNames =
    lib.optional ownsPostgres "usesend-postgres"
    ++ lib.optional ownsRedis "usesend-redis"
    ++ lib.optional ownsMinio "usesend-minio";
  sharedEnvironmentFiles =
    lib.optional (!ownsPostgres) cfg.postgres.shared.environmentFile
    ++ lib.optional (!ownsRedis) cfg.redis.shared.environmentFile
    ++ lib.optional (!ownsMinio) cfg.minio.shared.environmentFile;
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

    postgres = {
      mode = lib.mkOption {
        type = lib.types.enum [
          "owned"
          "shared"
        ];
        default = "owned";
        description = "Whether useSend owns PostgreSQL or connects to a shared instance.";
      };
      owned.image = lib.mkOption {
        type = lib.types.str;
        default = "docker.io/library/postgres:16";
        description = "OCI image used for the owned PostgreSQL instance.";
      };
      shared.environmentFile = lib.mkOption {
        type = lib.types.path;
        description = "Runtime environment file containing useSend's shared PostgreSQL connection settings.";
      };
    };

    redis = {
      mode = lib.mkOption {
        type = lib.types.enum [
          "owned"
          "shared"
        ];
        default = "owned";
        description = "Whether useSend owns Redis or connects to a shared instance.";
      };
      owned.image = lib.mkOption {
        type = lib.types.str;
        default = "docker.io/library/redis:7";
        description = "OCI image used for the owned Redis instance.";
      };
      shared.environmentFile = lib.mkOption {
        type = lib.types.path;
        description = "Runtime environment file containing useSend's shared Redis connection settings.";
      };
    };

    minio = {
      mode = lib.mkOption {
        type = lib.types.enum [
          "owned"
          "shared"
        ];
        default = "owned";
        description = "Whether useSend owns MinIO or connects to shared S3-compatible storage.";
      };
      owned.image = lib.mkOption {
        type = lib.types.str;
        default = "docker.io/minio/minio:latest";
        description = "OCI image used for the owned MinIO instance.";
      };
      shared.environmentFile = lib.mkOption {
        type = lib.types.path;
        description = "Runtime environment file containing useSend's shared object-storage settings.";
      };
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
        environmentFiles = [ cfg.environmentFile ] ++ sharedEnvironmentFiles;
        environment = {
          PORT = toString cfg.port;
          NEXT_PUBLIC_IS_CLOUD = "false";
        }
        // cfg.environment;
        labels = updateLabels;
      };
    }
    // lib.optionalAttrs ownsPostgres {
      usesend-postgres = {
        image = cfg.postgres.owned.image;
        networks = [ "selfhosted" ];
        environmentFiles = [ cfg.environmentFile ];
        volumes = [ "usesend-postgres:/var/lib/postgresql/data" ];
        labels = updateLabels;
      };
    }
    // lib.optionalAttrs ownsRedis {
      usesend-redis = {
        image = cfg.redis.owned.image;
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
    // lib.optionalAttrs ownsMinio {
      usesend-minio = {
        image = cfg.minio.owned.image;
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
