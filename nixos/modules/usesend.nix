{
  config,
  lib,
  ...
}:

let
  root = config.virtualisation.oci-containers.namedContainers;
  cfg = root.usesend;
  runtime = config.virtualisation.quadlet;
  quadlet = config.virtualisation.quadlet;
  selfhostedNetwork = quadlet.networks.selfhosted.ref;
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
  dependencyRefs = map (name: quadlet.containers.${name}.ref) dependencyNames;
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
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    virtualisation.quadlet.containers = {
      usesend = {
        unitConfig = {
          Documentation = [ "https://github.com/usesend/useSend#readme" ];
          Requires = dependencyRefs;
          After = dependencyRefs;
        };
        containerConfig = {
          image = cfg.image;
          publishPorts = [ "${cfg.host}:${toString cfg.port}:${toString cfg.port}" ];
          networks = [ selfhostedNetwork ];
          environmentFiles = map toString ([ cfg.environmentFile ] ++ sharedEnvironmentFiles);
          environments = {
            PORT = toString cfg.port;
            NEXT_PUBLIC_IS_CLOUD = "false";
          }
          // cfg.environment;
          autoUpdate = if runtime.autoUpdate.enable then "registry" else null;
        };
      };
    }
    // lib.optionalAttrs ownsPostgres {
      usesend-postgres = {
        unitConfig.Documentation = [ "https://github.com/usesend/useSend#readme" ];
        containerConfig = {
          image = cfg.postgres.owned.image;
          networks = [ selfhostedNetwork ];
          environmentFiles = [ (toString cfg.environmentFile) ];
          volumes = [ "usesend-postgres:/var/lib/postgresql/data" ];
          autoUpdate = if runtime.autoUpdate.enable then "registry" else null;
        };
      };
    }
    // lib.optionalAttrs ownsRedis {
      usesend-redis = {
        unitConfig.Documentation = [ "https://github.com/usesend/useSend#readme" ];
        containerConfig = {
          image = cfg.redis.owned.image;
          networks = [ selfhostedNetwork ];
          volumes = [ "usesend-redis:/data" ];
          exec = [
            "redis-server"
            "--maxmemory-policy"
            "noeviction"
          ];
          autoUpdate = if runtime.autoUpdate.enable then "registry" else null;
        };
      };
    }
    // lib.optionalAttrs ownsMinio {
      usesend-minio = {
        unitConfig.Documentation = [ "https://github.com/usesend/useSend#readme" ];
        containerConfig = {
          image = cfg.minio.owned.image;
          networks = [ selfhostedNetwork ];
          environmentFiles = [ (toString cfg.environmentFile) ];
          volumes = [ "usesend-minio:/data" ];
          exec = [
            "server"
            "/data"
            "--console-address"
            ":9001"
            "--address"
            ":9002"
          ];
          autoUpdate = if runtime.autoUpdate.enable then "registry" else null;
        };
      };
    };
  };
}
