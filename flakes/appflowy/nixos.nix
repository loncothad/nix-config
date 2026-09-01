{
  config,
  lib,
  pkgs,
  ...
}:

let
  root = config.virtualisation.oci-containers.namedContainers;
  cfg = root.appflowy;
  runtime = root;

  runtimeEnvironment = "/run/appflowy/environment";

  websocketBaseUrl =
    if cfg.websocketBaseUrl != null then
      cfg.websocketBaseUrl
    else if lib.hasPrefix "https://" cfg.baseUrl then
      "wss://${lib.removePrefix "https://" cfg.baseUrl}/ws/v2"
    else if lib.hasPrefix "http://" cfg.baseUrl then
      "ws://${lib.removePrefix "http://" cfg.baseUrl}/ws/v2"
    else
      "ws://${cfg.baseUrl}/ws/v2";

  ownsPostgres = cfg.postgres.mode == "owned";
  ownsRedis = cfg.redis.mode == "owned";
  ownsObjectStorage = cfg.objectStorage.mode == "owned";
  postgresHost = if ownsPostgres then "appflowy-postgres" else cfg.postgres.shared.host;
  postgresPort = if ownsPostgres then 5432 else cfg.postgres.shared.port;
  postgresUser = if ownsPostgres then cfg.postgres.owned.user else cfg.postgres.shared.user;
  postgresDatabase =
    if ownsPostgres then cfg.postgres.owned.database else cfg.postgres.shared.database;
  redisUri = if ownsRedis then "redis://appflowy-redis:6379" else cfg.redis.shared.uri;
  objectStorageEndpoint =
    if ownsObjectStorage then "http://appflowy-minio:9000" else cfg.objectStorage.shared.endpoint;
  objectStorageUsesMinio = ownsObjectStorage || cfg.objectStorage.shared.useMinio;
  objectStorageCreatesBucket = ownsObjectStorage || cfg.objectStorage.shared.createBucket;
  presignedUrlEndpoint =
    if ownsObjectStorage then
      "${cfg.baseUrl}/minio-api"
    else
      cfg.objectStorage.shared.presignedUrlEndpoint;

  updateLabels = lib.optionalAttrs runtime.autoUpdate.enable {
    "io.containers.autoupdate" = "registry";
  };

  commonEnvironmentFiles = [
    cfg.environmentFile
    runtimeEnvironment
  ];

  nginxConfig = pkgs.writeText "appflowy-nginx.conf" ''
    events {
      worker_connections 1024;
    }

    http {
      map $http_upgrade $connection_upgrade {
        default upgrade;
        "" close;
      }

      server {
        listen 80;
        client_max_body_size 10M;
        underscores_in_headers on;

        location /gotrue/ {
          proxy_pass http://appflowy-gotrue:9999;
          rewrite ^/gotrue(/.*)$ $1 break;
          proxy_set_header Host $http_host;
          proxy_pass_request_headers on;
        }

        location /ws {
          proxy_pass http://appflowy-cloud:8000;
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "Upgrade";
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_read_timeout 86400s;
        }

        location /api {
          proxy_pass http://appflowy-cloud:8000;
          proxy_set_header X-Request-Id $request_id;
          proxy_set_header Host $http_host;
          proxy_read_timeout 600s;
          proxy_connect_timeout 600s;
          proxy_send_timeout 600s;
          proxy_request_buffering off;
          proxy_buffering off;
          client_max_body_size 2G;
        }

        location /ai/ {
          proxy_pass http://appflowy-cloud:8000;
          proxy_set_header X-Request-Id $request_id;
          proxy_set_header Host $http_host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        }

        ${lib.optionalString ownsObjectStorage ''
          location /minio/ {
          proxy_pass http://appflowy-minio:9001;
          rewrite ^/minio/(.*) /$1 break;
          proxy_set_header Host $http_host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
          proxy_connect_timeout 300s;
          chunked_transfer_encoding off;
          }

          location /minio-api/ {
          proxy_pass http://appflowy-minio:9000;
          proxy_set_header Host "appflowy-minio:9000";
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          rewrite ^/minio-api/(.*) /$1 break;
          proxy_connect_timeout 300s;
          proxy_read_timeout 600s;
          proxy_send_timeout 600s;
          proxy_request_buffering off;
          proxy_http_version 1.1;
          proxy_set_header Connection "";
          chunked_transfer_encoding off;
          client_max_body_size 0;
          }
        ''}

        location /console {
          proxy_pass http://appflowy-admin:3000;
          proxy_set_header X-Forwarded-Host $http_host;
          proxy_set_header Host $http_host;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
        }

        location / {
          proxy_pass http://appflowy-web:80;
          proxy_set_header X-Scheme $scheme;
          proxy_set_header Host $host;
        }
      }
    }
  '';

  environmentSetup = pkgs.writeShellScript "appflowy-environment" ''
    set -eu
    umask 0077

    : "''${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"
    : "''${GOTRUE_ADMIN_EMAIL:?GOTRUE_ADMIN_EMAIL is required}"
    : "''${GOTRUE_ADMIN_PASSWORD:?GOTRUE_ADMIN_PASSWORD is required}"
    : "''${GOTRUE_JWT_SECRET:?GOTRUE_JWT_SECRET is required}"
    : "''${APPFLOWY_S3_ACCESS_KEY:?APPFLOWY_S3_ACCESS_KEY is required}"
    : "''${APPFLOWY_S3_SECRET_KEY:?APPFLOWY_S3_SECRET_KEY is required}"

    database_password="''${POSTGRES_PASSWORD_URL_ENCODED:-$POSTGRES_PASSWORD}"
    base_url=${lib.escapeShellArg cfg.baseUrl}
    websocket_base_url=${lib.escapeShellArg websocketBaseUrl}
    postgres_user=${lib.escapeShellArg postgresUser}
    postgres_database=${lib.escapeShellArg postgresDatabase}
    postgres_host=${lib.escapeShellArg postgresHost}
    postgres_port=${lib.escapeShellArg (toString postgresPort)}
    redis_uri=${lib.escapeShellArg redisUri}
    minio_endpoint=${lib.escapeShellArg objectStorageEndpoint}
    presigned_url_endpoint=${lib.escapeShellArg presignedUrlEndpoint}
    s3_bucket=${lib.escapeShellArg cfg.objectStorage.bucket}
    s3_region=${lib.escapeShellArg cfg.objectStorage.region}

    cat > ${runtimeEnvironment} <<EOF
    POSTGRES_HOST=$postgres_host
    POSTGRES_PORT=$postgres_port
    POSTGRES_USER=$postgres_user
    POSTGRES_DB=$postgres_database
    POSTGRES_PASSWORD=$POSTGRES_PASSWORD
    PGPORT=$postgres_port
    MINIO_ROOT_USER=$APPFLOWY_S3_ACCESS_KEY
    MINIO_ROOT_PASSWORD=$APPFLOWY_S3_SECRET_KEY
    MINIO_BROWSER_REDIRECT_URL=$base_url/minio
    APPFLOWY_DATABASE_URL=postgres://$postgres_user:$database_password@$postgres_host:$postgres_port/$postgres_database
    APPFLOWY_REDIS_URI=$redis_uri
    APPFLOWY_GOTRUE_BASE_URL=http://appflowy-gotrue:9999
    APPFLOWY_GOTRUE_JWT_SECRET=$GOTRUE_JWT_SECRET
    APPFLOWY_S3_CREATE_BUCKET=${lib.boolToString objectStorageCreatesBucket}
    APPFLOWY_S3_USE_MINIO=${lib.boolToString objectStorageUsesMinio}
    APPFLOWY_S3_MINIO_URL=$minio_endpoint
    APPFLOWY_S3_ACCESS_KEY=$APPFLOWY_S3_ACCESS_KEY
    APPFLOWY_S3_SECRET_KEY=$APPFLOWY_S3_SECRET_KEY
    APPFLOWY_S3_BUCKET=$s3_bucket
    APPFLOWY_S3_REGION=$s3_region
    APPFLOWY_S3_PRESIGNED_URL_ENDPOINT=$presigned_url_endpoint
    APPFLOWY_ACCESS_CONTROL=true
    APPFLOWY_DATABASE_MAX_CONNECTIONS=40
    APPFLOWY_BASE_URL=$base_url
    APPFLOWY_WEB_URL=$base_url
    APPFLOWY_WEBSOCKET_BASE_URL=$websocket_base_url
    APPFLOWY_WS_BASE_URL=$websocket_base_url
    API_EXTERNAL_URL=$base_url/gotrue
    DATABASE_URL=postgres://$postgres_user:$database_password@$postgres_host:$postgres_port/$postgres_database?search_path=auth
    GOTRUE_DATABASE_URL=postgres://$postgres_user:$database_password@$postgres_host:$postgres_port/$postgres_database?search_path=auth
    GOTRUE_ADMIN_EMAIL=$GOTRUE_ADMIN_EMAIL
    GOTRUE_ADMIN_PASSWORD=$GOTRUE_ADMIN_PASSWORD
    GOTRUE_JWT_SECRET=$GOTRUE_JWT_SECRET
    GOTRUE_JWT_EXP=604800
    GOTRUE_SITE_URL=appflowy-flutter://
    GOTRUE_URI_ALLOW_LIST=**
    GOTRUE_JWT_ADMIN_GROUP_NAME=supabase_admin
    GOTRUE_DB_DRIVER=postgres
    GOTRUE_DISABLE_SIGNUP=${lib.boolToString cfg.disableSignup}
    GOTRUE_MAILER_AUTOCONFIRM=${lib.boolToString cfg.mailerAutoconfirm}
    GOTRUE_MAILER_URLPATHS_CONFIRMATION=/gotrue/verify
    GOTRUE_MAILER_URLPATHS_INVITE=/gotrue/verify
    GOTRUE_MAILER_URLPATHS_RECOVERY=/gotrue/verify
    GOTRUE_MAILER_URLPATHS_EMAIL_CHANGE=/gotrue/verify
    PORT=9999
    AI_ENABLED=${lib.boolToString cfg.ai.enable}
    AI_SERVER_HOST=appflowy-ai
    AI_SERVER_PORT=5001
    AI_DATABASE_URL=postgresql+psycopg://$postgres_user:$database_password@$postgres_host:$postgres_port/$postgres_database
    AI_REDIS_URL=$redis_uri
    AI_USE_MINIO=${lib.boolToString objectStorageUsesMinio}
    AI_MINIO_URL=$minio_endpoint
    AI_APPFLOWY_HOST=$base_url
    OPENAI_API_KEY=''${AI_OPENAI_API_KEY:-}
    APPFLOWY_WORKER_REDIS_URL=$redis_uri
    APPFLOWY_WORKER_DATABASE_URL=postgres://$postgres_user:$database_password@$postgres_host:$postgres_port/$postgres_database
    APPFLOWY_WORKER_DATABASE_NAME=$postgres_database
    APPFLOWY_SEARCH_HOST=[::]
    APPFLOWY_SEARCH_PORT=4002
    APPFLOWY_SEARCH_DATABASE_URL=postgres://$postgres_user:$database_password@$postgres_host:$postgres_port/$postgres_database
    APPFLOWY_SEARCH_REDIS_URL=$redis_uri
    APPFLOWY_SEARCH_SERVICE_URL=http://appflowy-search:4002
    APPFLOWY_BACKGROUND_INDEXER_ENABLED=true
    APPFLOWY_KEYWORD_SEARCH_ENABLED=true
    APPFLOWY_KEYWORD_WORKER_ENABLED=true
    APPFLOWY_KEYWORD_INDEX_DIR=/var/lib/appflowy/keyword_index
    EOF
  '';

  dependencyNames =
    lib.optional ownsPostgres "appflowy-postgres"
    ++ lib.optional ownsRedis "appflowy-redis"
    ++ lib.optional ownsObjectStorage "appflowy-minio";

  coreContainerNames = dependencyNames ++ [
    "appflowy-gotrue"
    "appflowy-cloud"
    "appflowy-admin"
    "appflowy-worker"
    "appflowy-search"
    "appflowy-web"
    "appflowy-nginx"
  ];

  containerNames = coreContainerNames ++ lib.optional cfg.ai.enable "appflowy-ai";
  containerUnits = map (name: "podman-${name}.service") containerNames;
in
{
  options.virtualisation.oci-containers.namedContainers.appflowy = {
    enable = lib.mkEnableOption "the self-hosted AppFlowy Cloud stack (documentation: https://docs.appflowy.io/docs/documentation/appflowy-cloud/deployment)";

    environmentFile = lib.mkOption {
      type = lib.types.path;
      example = "/run/agenix/appflowy.env";
      description = ''
        Secret environment file. It must define POSTGRES_PASSWORD,
        GOTRUE_ADMIN_EMAIL, GOTRUE_ADMIN_PASSWORD, GOTRUE_JWT_SECRET,
        APPFLOWY_S3_ACCESS_KEY, and APPFLOWY_S3_SECRET_KEY. An optional
        POSTGRES_PASSWORD_URL_ENCODED value is used in database URLs.
      '';
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host address on which the AppFlowy proxy is published.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "Host port on which the AppFlowy proxy is published.";
    };

    baseUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://localhost:8000";
      description = "Public AppFlowy URL without a trailing slash.";
    };

    websocketBaseUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "wss://appflowy.example.com/ws/v2";
      description = "Public WebSocket URL, derived from baseUrl when null.";
    };

    postgres = {
      mode = lib.mkOption {
        type = lib.types.enum [
          "owned"
          "shared"
        ];
        default = "owned";
        description = "Whether AppFlowy owns PostgreSQL or connects to a shared instance.";
      };

      owned = {
        image = lib.mkOption {
          type = lib.types.str;
          default = "docker.io/pgvector/pgvector:pg16";
          description = "OCI image used for the owned PostgreSQL instance.";
        };
        user = lib.mkOption {
          type = lib.types.str;
          default = "postgres";
          description = "PostgreSQL user created in the owned instance.";
        };
        database = lib.mkOption {
          type = lib.types.str;
          default = "postgres";
          description = "PostgreSQL database created in the owned instance.";
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
          default = "appflowy";
          description = "PostgreSQL user allocated to AppFlowy.";
        };
        database = lib.mkOption {
          type = lib.types.str;
          default = "appflowy";
          description = "PostgreSQL database allocated to AppFlowy.";
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
        description = "Whether AppFlowy owns Redis or connects to a shared instance.";
      };
      owned.image = lib.mkOption {
        type = lib.types.str;
        default = "docker.io/library/redis:latest";
        description = "OCI image used for the owned Redis instance.";
      };
      shared.uri = lib.mkOption {
        type = lib.types.str;
        example = "rediss://redis.internal:6379";
        description = ''
          URI of the shared Redis instance. This is stored in the Nix store,
          so credentials should remain in environmentFile.
        '';
      };
    };

    objectStorage = {
      mode = lib.mkOption {
        type = lib.types.enum [
          "owned"
          "shared"
        ];
        default = "owned";
        description = "Whether AppFlowy owns MinIO or uses shared S3-compatible storage.";
      };
      bucket = lib.mkOption {
        type = lib.types.str;
        default = "appflowy";
        description = "Object-storage bucket used by AppFlowy services.";
      };
      region = lib.mkOption {
        type = lib.types.str;
        default = "us-east-1";
        description = "Object-storage region used by AppFlowy services.";
      };
      owned.image = lib.mkOption {
        type = lib.types.str;
        default = "docker.io/minio/minio:latest";
        description = "OCI image used for the owned MinIO instance.";
      };
      shared = {
        endpoint = lib.mkOption {
          type = lib.types.str;
          example = "https://s3.internal";
          description = "API endpoint of the shared S3-compatible service.";
        };
        presignedUrlEndpoint = lib.mkOption {
          type = lib.types.str;
          example = "https://objects.example.com";
          description = "Public endpoint used in generated presigned object URLs.";
        };
        useMinio = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether the shared service uses MinIO semantics.";
        };
        createBucket = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether AppFlowy should create its bucket in shared storage.";
        };
      };
    };

    ai.enable = lib.mkEnableOption "the optional AppFlowy AI service";

    mailerAutoconfirm = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatically confirm new GoTrue users without SMTP verification.";
    };

    disableSignup = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Disable public account registration in GoTrue.";
    };

    images = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        nginx = "docker.io/library/nginx:latest";
        gotrue = "docker.io/appflowyinc/gotrue:latest";
        cloud = "docker.io/appflowyinc/appflowy_cloud:latest";
        admin = "docker.io/appflowyinc/admin_frontend:latest";
        ai = "docker.io/appflowyinc/appflowy_ai:latest";
        worker = "docker.io/appflowyinc/appflowy_worker:latest";
        search = "docker.io/appflowyinc/appflowy_search:latest";
        web = "docker.io/appflowyinc/appflowy_web:latest";
      };
      description = "OCI images used by the AppFlowy Cloud stack.";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional non-secret environment variables passed to AppFlowy services.";
    };

    openFirewall = lib.mkEnableOption "the AppFlowy proxy port in the firewall";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !lib.hasSuffix "/" cfg.baseUrl;
        message = "AppFlowy baseUrl must not have a trailing slash.";
      }
    ];

    virtualisation.oci-containers.namedContainers.enable = true;
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    virtualisation.oci-containers.containers = {
      appflowy-gotrue = {
        image = cfg.images.gotrue;
        networks = [ "selfhosted" ];
        dependsOn = lib.optional ownsPostgres "appflowy-postgres";
        environmentFiles = commonEnvironmentFiles;
        environment = cfg.environment;
        labels = updateLabels;
      };

      appflowy-cloud = {
        image = cfg.images.cloud;
        networks = [ "selfhosted" ];
        dependsOn = dependencyNames ++ [ "appflowy-gotrue" ];
        environmentFiles = commonEnvironmentFiles;
        environment = {
          RUST_LOG = "info";
          APPFLOWY_ENVIRONMENT = "production";
        }
        // cfg.environment;
        labels = updateLabels;
      };

      appflowy-admin = {
        image = cfg.images.admin;
        networks = [ "selfhosted" ];
        dependsOn = [
          "appflowy-gotrue"
          "appflowy-cloud"
        ];
        environmentFiles = commonEnvironmentFiles;
        environment = {
          APPFLOWY_GOTRUE_BASE_URL = "http://appflowy-gotrue:9999";
          APPFLOWY_BASE_URL = "http://appflowy-cloud:8000";
        }
        // cfg.environment;
        labels = updateLabels;
      };

      appflowy-worker = {
        image = cfg.images.worker;
        networks = [ "selfhosted" ];
        dependsOn = lib.optional ownsPostgres "appflowy-postgres" ++ [ "appflowy-cloud" ];
        environmentFiles = commonEnvironmentFiles;
        environment = {
          RUST_LOG = "info";
          APPFLOWY_ENVIRONMENT = "production";
          APPFLOWY_WORKER_ENVIRONMENT = "production";
          APPFLOWY_WORKER_IMPORT_TICK_INTERVAL = "30";
        }
        // cfg.environment;
        labels = updateLabels;
      };

      appflowy-search = {
        image = cfg.images.search;
        networks = [ "selfhosted" ];
        dependsOn = dependencyNames;
        environmentFiles = commonEnvironmentFiles;
        environment = {
          RUST_LOG = "info";
        }
        // cfg.environment;
        volumes = [ "appflowy-search:/var/lib/appflowy/keyword_index" ];
        labels = updateLabels;
      };

      appflowy-web = {
        image = cfg.images.web;
        networks = [ "selfhosted" ];
        dependsOn = [ "appflowy-cloud" ];
        environmentFiles = commonEnvironmentFiles;
        environment = cfg.environment;
        labels = updateLabels;
      };

      appflowy-nginx = {
        image = cfg.images.nginx;
        ports = [ "${cfg.host}:${toString cfg.port}:80" ];
        networks = [ "selfhosted" ];
        dependsOn = lib.optional ownsObjectStorage "appflowy-minio" ++ [
          "appflowy-gotrue"
          "appflowy-cloud"
          "appflowy-admin"
          "appflowy-web"
        ];
        volumes = [ "${nginxConfig}:/etc/nginx/nginx.conf:ro" ];
        labels = updateLabels;
      };
    }
    // lib.optionalAttrs cfg.ai.enable {
      appflowy-ai = {
        image = cfg.images.ai;
        networks = [ "selfhosted" ];
        dependsOn = dependencyNames ++ [ "appflowy-cloud" ];
        environmentFiles = commonEnvironmentFiles;
        environment = cfg.environment;
        labels = updateLabels;
      };
    }
    // lib.optionalAttrs ownsPostgres {
      appflowy-postgres = {
        image = cfg.postgres.owned.image;
        networks = [ "selfhosted" ];
        environmentFiles = commonEnvironmentFiles;
        volumes = [ "appflowy-postgres:/var/lib/postgresql/data" ];
        cmd = [
          "postgres"
          "-c"
          "port=5432"
        ];
        labels = updateLabels;
      };
    }
    // lib.optionalAttrs ownsRedis {
      appflowy-redis = {
        image = cfg.redis.owned.image;
        networks = [ "selfhosted" ];
        volumes = [ "appflowy-redis:/data" ];
        labels = updateLabels;
      };
    }
    // lib.optionalAttrs ownsObjectStorage {
      appflowy-minio = {
        image = cfg.objectStorage.owned.image;
        networks = [ "selfhosted" ];
        environmentFiles = commonEnvironmentFiles;
        volumes = [ "appflowy-minio:/data" ];
        cmd = [
          "server"
          "/data"
          "--console-address"
          ":9001"
        ];
        labels = updateLabels;
      };
    };

    systemd.services =
      lib.genAttrs (map (name: "podman-${name}") containerNames) (_: {
        documentation = [ "https://docs.appflowy.io/docs/documentation/appflowy-cloud/deployment" ];
        after = [
          "selfhosted-podman-network.service"
          "appflowy-environment.service"
        ];
        requires = [
          "selfhosted-podman-network.service"
          "appflowy-environment.service"
        ];
      })
      // {
        appflowy-environment = {
          description = "Prepare the AppFlowy Cloud runtime environment";
          documentation = [ "https://docs.appflowy.io/docs/documentation/appflowy-cloud/deployment" ];
          wantedBy = [ "multi-user.target" ];
          before = containerUnits;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            EnvironmentFile = cfg.environmentFile;
            RuntimeDirectory = "appflowy";
            RuntimeDirectoryMode = "0700";
            ExecStart = environmentSetup;
          };
        };
      };
  };
}
