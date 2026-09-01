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
    postgres_user=${lib.escapeShellArg cfg.postgres.user}
    postgres_database=${lib.escapeShellArg cfg.postgres.database}
    s3_bucket=${lib.escapeShellArg cfg.s3Bucket}
    s3_region=${lib.escapeShellArg cfg.s3Region}

    cat > ${runtimeEnvironment} <<EOF
    POSTGRES_HOST=appflowy-postgres
    POSTGRES_PORT=5432
    POSTGRES_USER=$postgres_user
    POSTGRES_DB=$postgres_database
    POSTGRES_PASSWORD=$POSTGRES_PASSWORD
    PGPORT=5432
    MINIO_ROOT_USER=$APPFLOWY_S3_ACCESS_KEY
    MINIO_ROOT_PASSWORD=$APPFLOWY_S3_SECRET_KEY
    MINIO_BROWSER_REDIRECT_URL=$base_url/minio
    APPFLOWY_DATABASE_URL=postgres://$postgres_user:$database_password@appflowy-postgres:5432/$postgres_database
    APPFLOWY_REDIS_URI=redis://appflowy-redis:6379
    APPFLOWY_GOTRUE_BASE_URL=http://appflowy-gotrue:9999
    APPFLOWY_GOTRUE_JWT_SECRET=$GOTRUE_JWT_SECRET
    APPFLOWY_S3_CREATE_BUCKET=true
    APPFLOWY_S3_USE_MINIO=true
    APPFLOWY_S3_MINIO_URL=http://appflowy-minio:9000
    APPFLOWY_S3_ACCESS_KEY=$APPFLOWY_S3_ACCESS_KEY
    APPFLOWY_S3_SECRET_KEY=$APPFLOWY_S3_SECRET_KEY
    APPFLOWY_S3_BUCKET=$s3_bucket
    APPFLOWY_S3_REGION=$s3_region
    APPFLOWY_S3_PRESIGNED_URL_ENDPOINT=$base_url/minio-api
    APPFLOWY_ACCESS_CONTROL=true
    APPFLOWY_DATABASE_MAX_CONNECTIONS=40
    APPFLOWY_BASE_URL=$base_url
    APPFLOWY_WEB_URL=$base_url
    APPFLOWY_WEBSOCKET_BASE_URL=$websocket_base_url
    APPFLOWY_WS_BASE_URL=$websocket_base_url
    API_EXTERNAL_URL=$base_url/gotrue
    DATABASE_URL=postgres://$postgres_user:$database_password@appflowy-postgres:5432/$postgres_database?search_path=auth
    GOTRUE_DATABASE_URL=postgres://$postgres_user:$database_password@appflowy-postgres:5432/$postgres_database?search_path=auth
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
    AI_DATABASE_URL=postgresql+psycopg://$postgres_user:$database_password@appflowy-postgres:5432/$postgres_database
    AI_REDIS_URL=redis://appflowy-redis:6379
    AI_USE_MINIO=true
    AI_MINIO_URL=http://appflowy-minio:9000
    AI_APPFLOWY_HOST=$base_url
    OPENAI_API_KEY=''${AI_OPENAI_API_KEY:-}
    APPFLOWY_WORKER_REDIS_URL=redis://appflowy-redis:6379
    APPFLOWY_WORKER_DATABASE_URL=postgres://$postgres_user:$database_password@appflowy-postgres:5432/$postgres_database
    APPFLOWY_WORKER_DATABASE_NAME=$postgres_database
    APPFLOWY_SEARCH_HOST=[::]
    APPFLOWY_SEARCH_PORT=4002
    APPFLOWY_SEARCH_DATABASE_URL=postgres://$postgres_user:$database_password@appflowy-postgres:5432/$postgres_database
    APPFLOWY_SEARCH_REDIS_URL=redis://appflowy-redis:6379
    APPFLOWY_SEARCH_SERVICE_URL=http://appflowy-search:4002
    APPFLOWY_BACKGROUND_INDEXER_ENABLED=true
    APPFLOWY_KEYWORD_SEARCH_ENABLED=true
    APPFLOWY_KEYWORD_WORKER_ENABLED=true
    APPFLOWY_KEYWORD_INDEX_DIR=/var/lib/appflowy/keyword_index
    EOF
  '';

  coreContainerNames = [
    "appflowy-postgres"
    "appflowy-redis"
    "appflowy-minio"
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
    enable = lib.mkEnableOption "the self-hosted AppFlowy Cloud stack";

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

    s3Bucket = lib.mkOption {
      type = lib.types.str;
      default = "appflowy";
      description = "MinIO bucket used by AppFlowy services.";
    };

    s3Region = lib.mkOption {
      type = lib.types.str;
      default = "us-east-1";
      description = "S3 region reported to AppFlowy services.";
    };

    postgres = {
      user = lib.mkOption {
        type = lib.types.str;
        default = "postgres";
        description = "PostgreSQL user used by AppFlowy.";
      };

      database = lib.mkOption {
        type = lib.types.str;
        default = "postgres";
        description = "PostgreSQL database used by AppFlowy.";
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
        minio = "docker.io/minio/minio:latest";
        postgres = "docker.io/pgvector/pgvector:pg16";
        redis = "docker.io/library/redis:latest";
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
      appflowy-postgres = {
        image = cfg.images.postgres;
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

      appflowy-redis = {
        image = cfg.images.redis;
        networks = [ "selfhosted" ];
        volumes = [ "appflowy-redis:/data" ];
        labels = updateLabels;
      };

      appflowy-minio = {
        image = cfg.images.minio;
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

      appflowy-gotrue = {
        image = cfg.images.gotrue;
        networks = [ "selfhosted" ];
        dependsOn = [ "appflowy-postgres" ];
        environmentFiles = commonEnvironmentFiles;
        environment = cfg.environment;
        labels = updateLabels;
      };

      appflowy-cloud = {
        image = cfg.images.cloud;
        networks = [ "selfhosted" ];
        dependsOn = [
          "appflowy-postgres"
          "appflowy-redis"
          "appflowy-minio"
          "appflowy-gotrue"
        ];
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
        dependsOn = [
          "appflowy-postgres"
          "appflowy-cloud"
        ];
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
        dependsOn = [
          "appflowy-postgres"
          "appflowy-redis"
          "appflowy-minio"
        ];
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
        dependsOn = [
          "appflowy-minio"
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
        dependsOn = [
          "appflowy-postgres"
          "appflowy-cloud"
        ];
        environmentFiles = commonEnvironmentFiles;
        environment = cfg.environment;
        labels = updateLabels;
      };
    };

    systemd.services =
      lib.genAttrs (map (name: "podman-${name}") containerNames) (_: {
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
