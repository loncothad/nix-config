{
  config,
  lib,
  ...
}:

let
  root = config.virtualisation.oci-containers.namedContainers;
  cfg = root.rybbit;
  runtime = root;
  updateLabels = lib.optionalAttrs runtime.autoUpdate.enable {
    "io.containers.autoupdate" = "registry";
  };
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
  containerNames = dependencyNames ++ [
    "rybbit-backend"
    "rybbit-client"
  ];
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
    virtualisation.oci-containers.namedContainers.enable = true;
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [
      cfg.backendPort
      cfg.clientPort
    ];

    virtualisation.oci-containers.containers = {
      rybbit-backend = {
        image = cfg.backendImage;
        ports = [ "${cfg.host}:${toString cfg.backendPort}:3001" ];
        networks = [ "selfhosted" ];
        dependsOn = dependencyNames;
        environmentFiles = [ cfg.environmentFile ];
        environment = {
          NODE_ENV = "production";
          CLICKHOUSE_HOST = clickhouseUrl;
          POSTGRES_HOST = postgresHost;
          POSTGRES_PORT = toString postgresPort;
          REDIS_HOST = redisHost;
          REDIS_PORT = toString redisPort;
        }
        // cfg.environment;
        labels = updateLabels;
      };

      rybbit-client = {
        image = cfg.clientImage;
        ports = [ "${cfg.host}:${toString cfg.clientPort}:3002" ];
        networks = [ "selfhosted" ];
        dependsOn = [ "rybbit-backend" ];
        environmentFiles = [ cfg.environmentFile ];
        environment = {
          NODE_ENV = "production";
        }
        // cfg.environment;
        labels = updateLabels;
      };
    }
    // lib.optionalAttrs ownsClickHouse {
      rybbit-clickhouse = {
        image = cfg.clickhouse.owned.image;
        networks = [ "selfhosted" ];
        environmentFiles = [ cfg.environmentFile ];
        volumes = [ "rybbit-clickhouse:/var/lib/clickhouse" ];
        labels = updateLabels;
      };
    }
    // lib.optionalAttrs ownsPostgres {
      rybbit-postgres = {
        image = cfg.postgres.owned.image;
        networks = [ "selfhosted" ];
        environmentFiles = [ cfg.environmentFile ];
        volumes = [ "rybbit-postgres:/var/lib/postgresql/data" ];
        labels = updateLabels;
      };
    }
    // lib.optionalAttrs ownsRedis {
      rybbit-redis = {
        image = cfg.redis.owned.image;
        networks = [ "selfhosted" ];
        environmentFiles = [ cfg.environmentFile ];
        volumes = [ "rybbit-redis:/data" ];
        cmd = [
          "sh"
          "-c"
          ''exec redis-server --requirepass "$REDIS_PASSWORD" --appendonly yes --appendfsync everysec --maxmemory-policy noeviction''
        ];
        labels = updateLabels;
      };
    };

    systemd.services = lib.genAttrs (map (name: "podman-${name}") containerNames) (_: {
      documentation = [ "https://rybbit.com/docs/self-hosting" ];
      after = [ "selfhosted-podman-network.service" ];
      requires = [ "selfhosted-podman-network.service" ];
    });
  };
}
