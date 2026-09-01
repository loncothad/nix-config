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

  postgresCommand = [
    "postgres"
  ]
  ++ lib.concatLists (
    lib.mapAttrsToList (name: value: [
      "-c"
      "${name}=${value}"
    ]) cfg.postgres.settings
  );

  environmentSetup = pkgs.writeShellScript "sub2api-environment" ''
    set -eu
    umask 0077

    : "''${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"
    : "''${ADMIN_PASSWORD:?ADMIN_PASSWORD is required}"
    : "''${JWT_SECRET:?JWT_SECRET is required}"
    : "''${TOTP_ENCRYPTION_KEY:?TOTP_ENCRYPTION_KEY is required}"

    postgres_user=${lib.escapeShellArg cfg.postgres.user}
    postgres_database=${lib.escapeShellArg cfg.postgres.database}
    admin_email=${lib.escapeShellArg cfg.adminEmail}
    timezone=${lib.escapeShellArg cfg.timezone}

    cat > ${runtimeEnvironment} <<EOF
    AUTO_SETUP=true
    SERVER_HOST=0.0.0.0
    SERVER_PORT=8080
    SERVER_MODE=release
    DATABASE_HOST=sub2api-postgres
    DATABASE_PORT=5432
    DATABASE_USER=$postgres_user
    DATABASE_PASSWORD=$POSTGRES_PASSWORD
    DATABASE_DBNAME=$postgres_database
    DATABASE_SSLMODE=disable
    POSTGRES_USER=$postgres_user
    POSTGRES_PASSWORD=$POSTGRES_PASSWORD
    POSTGRES_DB=$postgres_database
    PGDATA=/var/lib/postgresql/data
    REDIS_HOST=sub2api-redis
    REDIS_PORT=6379
    REDIS_PASSWORD=''${REDIS_PASSWORD:-}
    REDISCLI_AUTH=''${REDIS_PASSWORD:-}
    ADMIN_EMAIL=$admin_email
    ADMIN_PASSWORD=$ADMIN_PASSWORD
    JWT_SECRET=$JWT_SECRET
    TOTP_ENCRYPTION_KEY=$TOTP_ENCRYPTION_KEY
    TZ=$timezone
    EOF
  '';

  containerNames = [
    "sub2api-postgres"
    "sub2api-redis"
    "sub2api"
  ];
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
        postgres = "docker.io/library/postgres:18-alpine";
        redis = "docker.io/library/redis:8-alpine";
      };
      description = "OCI images used by the Sub2API stack.";
    };

    postgres = {
      user = lib.mkOption {
        type = lib.types.str;
        default = "sub2api";
        description = "PostgreSQL user used by Sub2API.";
      };

      database = lib.mkOption {
        type = lib.types.str;
        default = "sub2api";
        description = "PostgreSQL database used by Sub2API.";
      };

      settings = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {
          max_connections = "100";
          shared_buffers = "128MB";
          effective_cache_size = "4GB";
          maintenance_work_mem = "64MB";
        };
        description = "PostgreSQL server settings passed with -c.";
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
      sub2api-postgres = {
        image = cfg.images.postgres;
        networks = [ "selfhosted" ];
        environmentFiles = environmentFiles;
        volumes = [ "sub2api-postgres:/var/lib/postgresql/data" ];
        cmd = postgresCommand;
        labels = updateLabels;
        extraOptions = [ "--ulimit=nofile=100000:100000" ];
      };

      sub2api-redis = {
        image = cfg.images.redis;
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

      sub2api = {
        image = cfg.images.app;
        ports = [ "${cfg.host}:${toString cfg.port}:8080" ];
        networks = [ "selfhosted" ];
        dependsOn = [
          "sub2api-postgres"
          "sub2api-redis"
        ];
        environmentFiles = environmentFiles;
        environment = cfg.environment;
        volumes = [ "sub2api-data:/app/data" ];
        labels = updateLabels;
        extraOptions = [
          "--security-opt=no-new-privileges"
          "--ulimit=nofile=100000:100000"
        ];
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
