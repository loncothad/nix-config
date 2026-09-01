{
  config,
  lib,
  ...
}:

let
  root = config.virtualisation.oci-containers.namedContainers;
  cfg = root.rybbit;
  runtime = config.virtualisation.quadlet;
  quadlet = config.virtualisation.quadlet;
  selfhostedNetwork = quadlet.networks.selfhosted.ref;
  ownsClickHouse = cfg.clickhouse.mode == "owned";
  ownsPostgres = cfg.postgres.mode == "owned";
  ownsRedis = cfg.redis.mode == "owned";
  clickhouseUrl =
    if ownsClickHouse then "http://rybbit-clickhouse:8123" else cfg.clickhouse.shared.url;
  postgresHost = if ownsPostgres then "rybbit-postgres" else cfg.postgres.shared.host;
  postgresPort = if ownsPostgres then 5432 else cfg.postgres.shared.port;
  redisHost = if ownsRedis then "rybbit-redis" else cfg.redis.shared.host;
  redisPort = if ownsRedis then 6379 else cfg.redis.shared.port;
  dependencyNames =
    lib.optional ownsClickHouse "rybbit-clickhouse"
    ++ lib.optional ownsPostgres "rybbit-postgres"
    ++ lib.optional ownsRedis "rybbit-redis";
  dependencyRefs = map (name: quadlet.containers.${name}.ref) dependencyNames;
in
{
  options.virtualisation.oci-containers.namedContainers.rybbit = {
    enable = lib.mkEnableOption "Rybbit web analytics (documentation: https://rybbit.com/docs/self-hosting)";

    backendImage = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/rybbit-io/rybbit-backend:latest";
      description = "OCI image used for the Rybbit backend.";
    };

    clientImage = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/rybbit-io/rybbit-client:latest";
      description = "OCI image used for the Rybbit client.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host address on which Rybbit is published.";
    };

    backendPort = lib.mkOption {
      type = lib.types.port;
      default = 3001;
      description = "Host port on which the Rybbit backend is published.";
    };

    clientPort = lib.mkOption {
      type = lib.types.port;
      default = 3002;
      description = "Host port on which the Rybbit client is published.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.path;
      example = "/run/agenix/rybbit.env";
      description = ''
        Secret environment file shared by Rybbit and its databases. See
        README.md for the required credentials and public URL.
      '';
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example.DISABLE_TELEMETRY = "true";
      description = ''
        Additional non-secret environment variables for the Rybbit backend and
        client. See https://rybbit.com/docs/self-hosting-guides/self-hosting-advanced.
      '';
    };

    clickhouse = {
      mode = lib.mkOption {
        type = lib.types.enum [
          "owned"
          "shared"
        ];
        default = "owned";
        description = "Whether Rybbit owns ClickHouse or connects to a shared instance.";
      };

      owned.image = lib.mkOption {
        type = lib.types.str;
        default = "docker.io/clickhouse/clickhouse-server:26.3.17.4";
        description = "OCI image used for the owned ClickHouse instance.";
      };

      shared.url = lib.mkOption {
        type = lib.types.str;
        example = "https://clickhouse.internal:8443";
        description = "HTTP endpoint of the shared ClickHouse instance.";
      };
    };

    postgres = {
      mode = lib.mkOption {
        type = lib.types.enum [
          "owned"
          "shared"
        ];
        default = "owned";
        description = "Whether Rybbit owns PostgreSQL or connects to a shared instance.";
      };

      owned.image = lib.mkOption {
        type = lib.types.str;
        default = "docker.io/library/postgres:17.4";
        description = "OCI image used for the owned PostgreSQL instance.";
      };

      shared.host = lib.mkOption {
        type = lib.types.str;
        example = "postgres.internal";
        description = "Host of the shared PostgreSQL instance.";
      };

      shared.port = lib.mkOption {
        type = lib.types.port;
        default = 5432;
        description = "Port of the shared PostgreSQL instance.";
      };
    };

    redis = {
      mode = lib.mkOption {
        type = lib.types.enum [
          "owned"
          "shared"
        ];
        default = "owned";
        description = "Whether Rybbit owns Redis or connects to a shared instance.";
      };

      owned.image = lib.mkOption {
        type = lib.types.str;
        default = "docker.io/library/redis:8.6.4-alpine";
        description = "OCI image used for the owned Redis instance.";
      };

      shared.host = lib.mkOption {
        type = lib.types.str;
        example = "redis.internal";
        description = "Host of the shared Redis instance.";
      };

      shared.port = lib.mkOption {
        type = lib.types.port;
        default = 6379;
        description = "Port of the shared Redis instance.";
      };
    };

    openFirewall = lib.mkEnableOption "the Rybbit frontend and backend ports in the firewall";
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [
      cfg.backendPort
      cfg.clientPort
    ];

    virtualisation.quadlet.containers = {
      rybbit-backend = {
        unitConfig = {
          Documentation = [ "https://rybbit.com/docs/self-hosting" ];
          Requires = dependencyRefs;
          After = dependencyRefs;
        };
        containerConfig = {
          image = cfg.backendImage;
          publishPorts = [ "${cfg.host}:${toString cfg.backendPort}:3001" ];
          networks = [ selfhostedNetwork ];
          environmentFiles = [ (toString cfg.environmentFile) ];
          environments = {
            NODE_ENV = "production";
            CLICKHOUSE_HOST = clickhouseUrl;
            POSTGRES_HOST = postgresHost;
            POSTGRES_PORT = toString postgresPort;
            REDIS_HOST = redisHost;
            REDIS_PORT = toString redisPort;
          }
          // cfg.environment;
          autoUpdate = if runtime.autoUpdate.enable then "registry" else null;
        };
      };

      rybbit-client = {
        unitConfig = {
          Documentation = [ "https://rybbit.com/docs/self-hosting" ];
          Requires = [ quadlet.containers.rybbit-backend.ref ];
          After = [ quadlet.containers.rybbit-backend.ref ];
        };
        containerConfig = {
          image = cfg.clientImage;
          publishPorts = [ "${cfg.host}:${toString cfg.clientPort}:3002" ];
          networks = [ selfhostedNetwork ];
          environmentFiles = [ (toString cfg.environmentFile) ];
          environments = {
            NODE_ENV = "production";
          }
          // cfg.environment;
          autoUpdate = if runtime.autoUpdate.enable then "registry" else null;
        };
      };
    }
    // lib.optionalAttrs ownsClickHouse {
      rybbit-clickhouse = {
        unitConfig.Documentation = [ "https://rybbit.com/docs/self-hosting" ];
        containerConfig = {
          image = cfg.clickhouse.owned.image;
          networks = [ selfhostedNetwork ];
          environmentFiles = [ (toString cfg.environmentFile) ];
          volumes = [ "rybbit-clickhouse:/var/lib/clickhouse" ];
          autoUpdate = if runtime.autoUpdate.enable then "registry" else null;
        };
      };
    }
    // lib.optionalAttrs ownsPostgres {
      rybbit-postgres = {
        unitConfig.Documentation = [ "https://rybbit.com/docs/self-hosting" ];
        containerConfig = {
          image = cfg.postgres.owned.image;
          networks = [ selfhostedNetwork ];
          environmentFiles = [ (toString cfg.environmentFile) ];
          volumes = [ "rybbit-postgres:/var/lib/postgresql/data" ];
          autoUpdate = if runtime.autoUpdate.enable then "registry" else null;
        };
      };
    }
    // lib.optionalAttrs ownsRedis {
      rybbit-redis = {
        unitConfig.Documentation = [ "https://rybbit.com/docs/self-hosting" ];
        containerConfig = {
          image = cfg.redis.owned.image;
          networks = [ selfhostedNetwork ];
          environmentFiles = [ (toString cfg.environmentFile) ];
          volumes = [ "rybbit-redis:/data" ];
          exec = [
            "sh"
            "-c"
            ''exec redis-server --requirepass "$REDIS_PASSWORD" --appendonly yes --appendfsync everysec --maxmemory-policy noeviction''
          ];
          autoUpdate = if runtime.autoUpdate.enable then "registry" else null;
        };
      };
    };
  };
}
