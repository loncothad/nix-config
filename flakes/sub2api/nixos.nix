{
  config,
  lib,
  pkgs,
  ...
}:

let
  root = config.virtualisation.oci-containers.namedContainers;
  cfg = root.sub2api;
  runtime = root;

  runtimeEnvironment = "/run/sub2api/environment";
  environmentFiles = [
    cfg.environmentFile
    runtimeEnvironment
  ];

  updateLabels = lib.optionalAttrs runtime.autoUpdate.enable {
    "io.containers.autoupdate" = "registry";
  };

  ownsPostgres = cfg.postgres.mode == "owned";
  ownsRedis = cfg.redis.mode == "owned";
  postgresHost = if ownsPostgres then "sub2api-postgres" else cfg.postgres.shared.host;
  postgresPort = if ownsPostgres then 5432 else cfg.postgres.shared.port;
  postgresUser = if ownsPostgres then cfg.postgres.owned.user else cfg.postgres.shared.user;
  postgresDatabase =
    if ownsPostgres then cfg.postgres.owned.database else cfg.postgres.shared.database;
  postgresSslMode = if ownsPostgres then "disable" else cfg.postgres.shared.sslMode;
  redisHost = if ownsRedis then "sub2api-redis" else cfg.redis.shared.host;
  redisPort = if ownsRedis then 6379 else cfg.redis.shared.port;

  postgresCommand = [
    "postgres"
  ]
  ++ lib.concatLists (
    lib.mapAttrsToList (name: value: [
      "-c"
      "${name}=${value}"
    ]) cfg.postgres.owned.settings
  );

  environmentSetup = pkgs.writeShellScript "sub2api-environment" ''
    set -eu
    umask 0077

    : "''${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"
    : "''${ADMIN_PASSWORD:?ADMIN_PASSWORD is required}"
    : "''${JWT_SECRET:?JWT_SECRET is required}"
    : "''${TOTP_ENCRYPTION_KEY:?TOTP_ENCRYPTION_KEY is required}"

    postgres_user=${lib.escapeShellArg postgresUser}
    postgres_database=${lib.escapeShellArg postgresDatabase}
    postgres_host=${lib.escapeShellArg postgresHost}
    postgres_port=${lib.escapeShellArg (toString postgresPort)}
    postgres_sslmode=${lib.escapeShellArg postgresSslMode}
    redis_host=${lib.escapeShellArg redisHost}
    redis_port=${lib.escapeShellArg (toString redisPort)}
    admin_email=${lib.escapeShellArg cfg.adminEmail}
    timezone=${lib.escapeShellArg cfg.timezone}

    cat > ${runtimeEnvironment} <<EOF
    AUTO_SETUP=true
    SERVER_HOST=0.0.0.0
    SERVER_PORT=8080
    SERVER_MODE=release
    DATABASE_HOST=$postgres_host
    DATABASE_PORT=$postgres_port
    DATABASE_USER=$postgres_user
    DATABASE_PASSWORD=$POSTGRES_PASSWORD
    DATABASE_DBNAME=$postgres_database
    DATABASE_SSLMODE=$postgres_sslmode
    POSTGRES_USER=$postgres_user
    POSTGRES_PASSWORD=$POSTGRES_PASSWORD
    POSTGRES_DB=$postgres_database
    PGDATA=/var/lib/postgresql/data
    REDIS_HOST=$redis_host
    REDIS_PORT=$redis_port
    REDIS_PASSWORD=''${REDIS_PASSWORD:-}
    REDISCLI_AUTH=''${REDIS_PASSWORD:-}
    ADMIN_EMAIL=$admin_email
    ADMIN_PASSWORD=$ADMIN_PASSWORD
    JWT_SECRET=$JWT_SECRET
    TOTP_ENCRYPTION_KEY=$TOTP_ENCRYPTION_KEY
    TZ=$timezone
    EOF
  '';

  dependencyNames =
    lib.optional ownsPostgres "sub2api-postgres" ++ lib.optional ownsRedis "sub2api-redis";
  containerNames = dependencyNames ++ [ "sub2api" ];
  containerUnits = map (name: "podman-${name}.service") containerNames;
in
{
  options.virtualisation.oci-containers.namedContainers.sub2api = {
    enable = lib.mkEnableOption "Sub2API AI API gateway (documentation: https://github.com/Wei-Shaw/sub2api#readme)";

    environmentFile = lib.mkOption {
      type = lib.types.path;
      example = "/run/agenix/sub2api.env";
      description = ''
        Secret environment file defining POSTGRES_PASSWORD, ADMIN_PASSWORD,
        JWT_SECRET, and TOTP_ENCRYPTION_KEY. REDIS_PASSWORD and optional
        upstream OAuth, payment, mail, and gateway variables may also be set.
      '';
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host address on which Sub2API is published.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Host port on which Sub2API is published.";
    };

    adminEmail = lib.mkOption {
      type = lib.types.str;
      default = "admin@sub2api.local";
      description = "Email address of the administrator created during automatic setup.";
    };

    timezone = lib.mkOption {
      type = lib.types.str;
      default = "UTC";
      example = "Europe/Istanbul";
      description = "Timezone used by the application and its dependencies.";
    };

    images = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        app = "docker.io/weishaw/sub2api:latest";
      };
      description = "OCI images used by the Sub2API application stack.";
    };

    postgres = {
      mode = lib.mkOption {
        type = lib.types.enum [
          "owned"
          "shared"
        ];
        default = "owned";
        description = "Whether Sub2API owns PostgreSQL or connects to a shared instance.";
      };

      owned = {
        image = lib.mkOption {
          type = lib.types.str;
          default = "docker.io/library/postgres:18-alpine";
          description = "OCI image used for the owned PostgreSQL instance.";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = "sub2api";
          description = "PostgreSQL user created in the owned instance.";
        };

        database = lib.mkOption {
          type = lib.types.str;
          default = "sub2api";
          description = "PostgreSQL database created in the owned instance.";
        };

        settings = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = {
            max_connections = "100";
            shared_buffers = "128MB";
            effective_cache_size = "4GB";
            maintenance_work_mem = "64MB";
          };
          description = "PostgreSQL settings passed to the owned server with -c.";
        };
      };

      shared = {
        host = lib.mkOption {
          type = lib.types.str;
          example = "postgres.internal";
          description = "Host of the shared PostgreSQL instance.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 5432;
          description = "Port of the shared PostgreSQL instance.";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = "sub2api";
          description = "PostgreSQL user allocated to Sub2API.";
        };

        database = lib.mkOption {
          type = lib.types.str;
          default = "sub2api";
          description = "PostgreSQL database allocated to Sub2API.";
        };

        sslMode = lib.mkOption {
          type = lib.types.str;
          default = "require";
          example = "verify-full";
          description = "TLS mode used for the shared PostgreSQL connection.";
        };
      };
    };

    redis = {
      mode = lib.mkOption {
        type = lib.types.enum [
          "owned"
          "shared"
        ];
        default = "owned";
        description = "Whether Sub2API owns Redis or connects to a shared instance.";
      };

      owned.image = lib.mkOption {
        type = lib.types.str;
        default = "docker.io/library/redis:8-alpine";
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

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional non-secret environment variables passed to Sub2API.";
    };

    openFirewall = lib.mkEnableOption "the Sub2API port in the firewall";
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.namedContainers.enable = true;
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    virtualisation.oci-containers.containers = {
      sub2api = {
        image = cfg.images.app;
        ports = [ "${cfg.host}:${toString cfg.port}:8080" ];
        networks = [ "selfhosted" ];
        dependsOn = dependencyNames;
        environmentFiles = environmentFiles;
        environment = cfg.environment;
        volumes = [ "sub2api-data:/app/data" ];
        labels = updateLabels;
        extraOptions = [
          "--security-opt=no-new-privileges"
          "--ulimit=nofile=100000:100000"
        ];
      };
    }
    // lib.optionalAttrs ownsPostgres {
      sub2api-postgres = {
        image = cfg.postgres.owned.image;
        networks = [ "selfhosted" ];
        environmentFiles = environmentFiles;
        volumes = [ "sub2api-postgres:/var/lib/postgresql/data" ];
        cmd = postgresCommand;
        labels = updateLabels;
        extraOptions = [ "--ulimit=nofile=100000:100000" ];
      };
    }
    // lib.optionalAttrs ownsRedis {
      sub2api-redis = {
        image = cfg.redis.owned.image;
        networks = [ "selfhosted" ];
        environmentFiles = environmentFiles;
        volumes = [ "sub2api-redis:/data" ];
        cmd = [
          "sh"
          "-c"
          ''exec redis-server --save 60 1 --appendonly yes --appendfsync everysec ''${REDIS_PASSWORD:+--requirepass "$REDIS_PASSWORD"}''
        ];
        labels = updateLabels;
        extraOptions = [ "--ulimit=nofile=100000:100000" ];
      };
    };

    systemd.services =
      lib.genAttrs (map (name: "podman-${name}") containerNames) (_: {
        documentation = [ "https://github.com/Wei-Shaw/sub2api#readme" ];
        after = [
          "selfhosted-podman-network.service"
          "sub2api-environment.service"
        ];
        requires = [
          "selfhosted-podman-network.service"
          "sub2api-environment.service"
        ];
      })
      // {
        sub2api-environment = {
          description = "Prepare the Sub2API runtime environment";
          documentation = [ "https://github.com/Wei-Shaw/sub2api#readme" ];
          wantedBy = [ "multi-user.target" ];
          before = containerUnits;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            EnvironmentFile = cfg.environmentFile;
            RuntimeDirectory = "sub2api";
            RuntimeDirectoryMode = "0700";
            ExecStart = environmentSetup;
          };
        };
      };
  };
}
