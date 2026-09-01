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
  dependencyNames =
    lib.optional cfg.clickhouse.createLocally "rybbit-clickhouse"
    ++ lib.optional cfg.postgres.createLocally "rybbit-postgres"
    ++ lib.optional cfg.redis.createLocally "rybbit-redis";
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
      createLocally = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to run a dedicated ClickHouse container.";
      };

      url = lib.mkOption {
        type = lib.types.str;
        default = "http://rybbit-clickhouse:8123";
        example = "https://clickhouse.internal:8443";
        description = "ClickHouse HTTP endpoint used by the Rybbit backend.";
      };
    };

    postgres = {
      createLocally = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to run a dedicated PostgreSQL container.";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "rybbit-postgres";
        description = "PostgreSQL host used by the Rybbit backend.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 5432;
        description = "PostgreSQL port used by the Rybbit backend.";
      };
    };

    redis = {
      createLocally = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to run a dedicated Redis container.";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "rybbit-redis";
        description = "Redis host used by the Rybbit backend.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 6379;
        description = "Redis port used by the Rybbit backend.";
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
          CLICKHOUSE_HOST = cfg.clickhouse.url;
          POSTGRES_HOST = cfg.postgres.host;
          POSTGRES_PORT = toString cfg.postgres.port;
          REDIS_HOST = cfg.redis.host;
          REDIS_PORT = toString cfg.redis.port;
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
    // lib.optionalAttrs cfg.clickhouse.createLocally {
      rybbit-clickhouse = {
        image = "docker.io/clickhouse/clickhouse-server:26.3.17.4";
        networks = [ "selfhosted" ];
        environmentFiles = [ cfg.environmentFile ];
        volumes = [ "rybbit-clickhouse:/var/lib/clickhouse" ];
        labels = updateLabels;
      };
    }
    // lib.optionalAttrs cfg.postgres.createLocally {
      rybbit-postgres = {
        image = "docker.io/library/postgres:17.4";
        networks = [ "selfhosted" ];
        environmentFiles = [ cfg.environmentFile ];
        volumes = [ "rybbit-postgres:/var/lib/postgresql/data" ];
        labels = updateLabels;
      };
    }
    // lib.optionalAttrs cfg.redis.createLocally {
      rybbit-redis = {
        image = "docker.io/library/redis:8.6.4-alpine";
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
