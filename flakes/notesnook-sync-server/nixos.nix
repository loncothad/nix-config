{
  config,
  lib,
  pkgs,
  ...
}:

let
  root = config.virtualisation.oci-containers.namedContainers;
  cfg = root.notesnook-sync-server;
  quadlet = config.virtualisation.quadlet;
  selfhostedNetwork = quadlet.networks.selfhosted.ref;
  runtimeEnvironment = "/run/notesnook-sync-server/environment";

  ownsMongoDB = cfg.mongodb.mode == "owned";
  ownsObjectStorage = cfg.objectStorage.mode == "owned";

  mongodbDependencies = lib.optional ownsMongoDB "notesnook-mongodb";
  storageDependencies = lib.optionals ownsObjectStorage [
    "notesnook-minio"
    "notesnook-minio-setup"
  ];

  commonEnvironment = {
    INSTANCE_NAME = cfg.instanceName;
    DISABLE_SIGNUPS = lib.boolToString cfg.disableSignups;
    SELF_HOSTED = "1";
    NOTESNOOK_SERVER_HOST = "notesnook-sync";
    NOTESNOOK_SERVER_PORT = "5264";
    IDENTITY_SERVER_HOST = "notesnook-identity";
    IDENTITY_SERVER_PORT = "8264";
    SSE_SERVER_HOST = "notesnook-sse";
    SSE_SERVER_PORT = "7264";
    IDENTITY_SERVER_URL = cfg.publicUrls.identity;
    AUTH_SERVER_PUBLIC_URL = cfg.publicUrls.identity;
    NOTESNOOK_APP_HOST = cfg.publicUrls.application;
    NOTESNOOK_APP_PUBLIC_URL = cfg.publicUrls.application;
    NOTESNOOK_API_PUBLIC_URL = cfg.publicUrls.sync;
    MONOGRAPH_PUBLIC_URL = cfg.publicUrls.monograph;
    ATTACHMENTS_SERVER_PUBLIC_URL = cfg.publicUrls.attachments;
  };

  ownedMongoEnvironment = {
    MONGODB_CONNECTION_STRING = "mongodb://notesnook-mongodb:27017/?replSet=rs0";
    MONGODB_CONNECTION_STRING_IDENTITY = "mongodb://notesnook-mongodb:27017/identity?replSet=rs0";
  };

  objectStorageEnvironment = {
    S3_INTERNAL_SERVICE_URL =
      if ownsObjectStorage then "http://notesnook-minio:9000" else cfg.objectStorage.shared.endpoint;
    S3_INTERNAL_BUCKET_NAME = cfg.objectStorage.bucket;
    S3_SERVICE_URL = cfg.publicUrls.attachments;
    S3_REGION = cfg.objectStorage.region;
    S3_BUCKET_NAME = cfg.objectStorage.bucket;
  };

  commonEnvironmentFiles = [
    (toString cfg.environmentFile)
    runtimeEnvironment
  ];

  identityEnvironmentFiles =
    commonEnvironmentFiles
    ++ lib.optional (!ownsMongoDB) (toString cfg.mongodb.shared.identityEnvironmentFile);
  syncEnvironmentFiles =
    commonEnvironmentFiles
    ++ lib.optional (!ownsMongoDB) (toString cfg.mongodb.shared.syncEnvironmentFile);

  environmentSetup = pkgs.writeShellScript "notesnook-sync-server-environment" ''
    set -eu
    umask 0077

    : "''${NOTESNOOK_API_SECRET:?NOTESNOOK_API_SECRET is required}"
    ${
      if ownsObjectStorage then
        ''
          : "''${MINIO_ROOT_USER:?MINIO_ROOT_USER is required for owned object storage}"
          : "''${MINIO_ROOT_PASSWORD:?MINIO_ROOT_PASSWORD is required for owned object storage}"
          s3_access_key_id=$MINIO_ROOT_USER
          s3_access_key=$MINIO_ROOT_PASSWORD
        ''
      else
        ''
          : "''${S3_ACCESS_KEY_ID:?S3_ACCESS_KEY_ID is required for shared object storage}"
          : "''${S3_ACCESS_KEY:?S3_ACCESS_KEY is required for shared object storage}"
          s3_access_key_id=$S3_ACCESS_KEY_ID
          s3_access_key=$S3_ACCESS_KEY
        ''
    }

    cat > ${runtimeEnvironment} <<EOF
    S3_ACCESS_KEY_ID=$s3_access_key_id
    S3_ACCESS_KEY=$s3_access_key
    EOF
  '';

  containerNames = [
    "notesnook-identity"
    "notesnook-sync"
    "notesnook-sse"
    "notesnook-monograph"
  ]
  ++ mongodbDependencies
  ++ storageDependencies;

  containerUnits = map (name: "${name}.service") containerNames;

  mkContainer =
    {
      image,
      dependencies ? [ ],
      environment ? { },
      environmentFiles ? commonEnvironmentFiles,
      publishPorts ? [ ],
      volumes ? [ ],
      exec ? null,
      entrypoint ? null,
      healthCmd ? null,
      serviceConfig ? { },
    }:
    let
      dependencyRefs = map (name: quadlet.containers.${name}.ref) dependencies;
    in
    {
      unitConfig = {
        Documentation = [ "https://github.com/streetwriters/notesnook-sync-server#using-docker" ];
        Requires = [ "notesnook-sync-server-environment.service" ] ++ dependencyRefs;
        After = [ "notesnook-sync-server-environment.service" ] ++ dependencyRefs;
      };
      inherit serviceConfig;
      containerConfig = {
        inherit image volumes publishPorts;
        networks = [ selfhostedNetwork ];
        environmentFiles = environmentFiles;
        environments = environment // cfg.environment;
        autoUpdate = if quadlet.autoUpdate.enable then "registry" else null;
        notify = if healthCmd == null then null else "healthy";
        healthCmd = healthCmd;
        healthInterval = if healthCmd == null then null else "40s";
        healthTimeout = if healthCmd == null then null else "30s";
        healthRetries = if healthCmd == null then null else 3;
        healthStartPeriod = if healthCmd == null then null else "60s";
      }
      // lib.optionalAttrs (exec != null) { inherit exec; }
      // lib.optionalAttrs (entrypoint != null) { inherit entrypoint; };
    };
in
{
  options.virtualisation.oci-containers.namedContainers.notesnook-sync-server = {
    enable = lib.mkEnableOption "Notesnook Sync Server (documentation: https://github.com/streetwriters/notesnook-sync-server#using-docker)";

    environmentFile = lib.mkOption {
      type = lib.types.path;
      example = "/run/agenix/notesnook.env";
      description = ''
        Runtime secret file containing NOTESNOOK_API_SECRET and the credentials
        required by the selected object-storage mode. It may also contain the
        optional SMTP and Twilio variables supported upstream.
      '';
    };

    instanceName = lib.mkOption {
      type = lib.types.str;
      default = "self-hosted-notesnook";
      description = "Name displayed for this self-hosted Notesnook instance.";
    };

    disableSignups = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether new account registration is disabled.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host address on which public Notesnook ports are published.";
    };

    ports = {
      sync = lib.mkOption {
        type = lib.types.port;
        default = 5264;
        description = "Host port for the Notesnook Sync API.";
      };
      monograph = lib.mkOption {
        type = lib.types.port;
        default = 6264;
        description = "Host port for Monograph.";
      };
      sse = lib.mkOption {
        type = lib.types.port;
        default = 7264;
        description = "Host port for the SSE service.";
      };
      identity = lib.mkOption {
        type = lib.types.port;
        default = 8264;
        description = "Host port for the Identity service.";
      };
      attachments = lib.mkOption {
        type = lib.types.port;
        default = 9000;
        description = "Host port for owned MinIO object storage.";
      };
    };

    publicUrls = {
      application = lib.mkOption {
        type = lib.types.str;
        default = "https://app.notesnook.com";
        description = "Public Notesnook web application URL.";
      };
      identity = lib.mkOption {
        type = lib.types.str;
        default = "http://localhost:8264";
        description = "Browser-accessible Identity service URL.";
      };
      sync = lib.mkOption {
        type = lib.types.str;
        default = "http://localhost:5264";
        description = "Browser-accessible Sync API URL.";
      };
      monograph = lib.mkOption {
        type = lib.types.str;
        default = "http://localhost:6264";
        description = "Browser-accessible Monograph URL.";
      };
      attachments = lib.mkOption {
        type = lib.types.str;
        default = "http://localhost:9000";
        description = "Browser-accessible attachment-storage URL.";
      };
    };

    mongodb = {
      mode = lib.mkOption {
        type = lib.types.enum [
          "owned"
          "shared"
        ];
        default = "owned";
        description = "Whether Notesnook owns MongoDB or uses a shared replica set.";
      };
      owned.image = lib.mkOption {
        type = lib.types.str;
        default = "docker.io/library/mongo:7.0.12";
        description = "OCI image used for owned MongoDB.";
      };
      shared = {
        identityEnvironmentFile = lib.mkOption {
          type = lib.types.path;
          description = "Runtime file defining MONGODB_CONNECTION_STRING for the Identity database.";
        };
        syncEnvironmentFile = lib.mkOption {
          type = lib.types.path;
          description = "Runtime file defining MONGODB_CONNECTION_STRING for the Sync database.";
        };
      };
    };

    objectStorage = {
      mode = lib.mkOption {
        type = lib.types.enum [
          "owned"
          "shared"
        ];
        default = "owned";
        description = "Whether Notesnook owns MinIO or uses shared S3-compatible storage.";
      };
      bucket = lib.mkOption {
        type = lib.types.str;
        default = "attachments";
        description = "S3 bucket used for Notesnook attachments.";
      };
      region = lib.mkOption {
        type = lib.types.str;
        default = "us-east-1";
        description = "S3 region used for attachment storage.";
      };
      owned = {
        image = lib.mkOption {
          type = lib.types.str;
          default = "docker.io/minio/minio:RELEASE.2024-07-29T22-14-52Z";
          description = "OCI image used for owned MinIO.";
        };
        setupImage = lib.mkOption {
          type = lib.types.str;
          default = "docker.io/minio/mc:RELEASE.2024-07-26T13-08-44Z";
          description = "OCI image used to create the owned attachment bucket.";
        };
      };
      shared.endpoint = lib.mkOption {
        type = lib.types.str;
        example = "https://s3.internal";
        description = "Internal API endpoint of shared S3-compatible storage.";
      };
    };

    images = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        identity = "docker.io/streetwriters/identity:latest";
        sync = "docker.io/streetwriters/notesnook-sync:latest";
        sse = "docker.io/streetwriters/sse:latest";
        monograph = "docker.io/streetwriters/monograph:latest";
      };
      description = "OCI images for the core Notesnook services.";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional non-secret environment variables passed to Notesnook containers.";
    };

    openFirewall = lib.mkEnableOption "all published Notesnook service ports in the firewall";
  };

  config = lib.mkIf cfg.enable {
    assertions = map (url: {
      assertion = !lib.hasSuffix "/" url;
      message = "Notesnook public URLs must not have trailing slashes.";
    }) (lib.attrValues cfg.publicUrls);

    virtualisation.quadlet.networks.selfhosted.networkConfig = {
      name = "selfhosted";
      interfaceName = "selfhosted0";
    };
    networking.firewall.interfaces.selfhosted0.allowedUDPPorts = [ 53 ];
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall (
      [
        cfg.ports.sync
        cfg.ports.monograph
        cfg.ports.sse
        cfg.ports.identity
      ]
      ++ lib.optional ownsObjectStorage cfg.ports.attachments
    );

    virtualisation.quadlet.containers = {
      notesnook-identity = mkContainer {
        image = cfg.images.identity;
        dependencies = mongodbDependencies;
        environmentFiles = identityEnvironmentFiles;
        publishPorts = [ "${cfg.host}:${toString cfg.ports.identity}:8264" ];
        environment =
          commonEnvironment
          // {
            MONGODB_DATABASE_NAME = "identity";
          }
          // lib.optionalAttrs ownsMongoDB {
            MONGODB_CONNECTION_STRING = ownedMongoEnvironment.MONGODB_CONNECTION_STRING_IDENTITY;
          };
        healthCmd = "wget --tries=1 -nv -q http://localhost:8264/health -O- || exit 1";
      };

      notesnook-sync = mkContainer {
        image = cfg.images.sync;
        dependencies = mongodbDependencies ++ storageDependencies ++ [ "notesnook-identity" ];
        environmentFiles = syncEnvironmentFiles;
        publishPorts = [ "${cfg.host}:${toString cfg.ports.sync}:5264" ];
        environment =
          commonEnvironment
          // objectStorageEnvironment
          // {
            MONGODB_DATABASE_NAME = "notesnook";
          }
          // lib.optionalAttrs ownsMongoDB {
            MONGODB_CONNECTION_STRING = ownedMongoEnvironment.MONGODB_CONNECTION_STRING;
          };
        healthCmd = "wget --tries=1 -nv -q http://localhost:5264/health -O- || exit 1";
      };

      notesnook-sse = mkContainer {
        image = cfg.images.sse;
        dependencies = [
          "notesnook-identity"
          "notesnook-sync"
        ];
        publishPorts = [ "${cfg.host}:${toString cfg.ports.sse}:7264" ];
        environment = commonEnvironment;
        healthCmd = "wget --tries=1 -nv -q http://localhost:7264/health -O- || exit 1";
      };

      notesnook-monograph = mkContainer {
        image = cfg.images.monograph;
        dependencies = [ "notesnook-sync" ];
        publishPorts = [ "${cfg.host}:${toString cfg.ports.monograph}:3000" ];
        environment = commonEnvironment // {
          NODE_ENV = "production";
          HOST = "0.0.0.0";
          API_HOST = cfg.publicUrls.sync;
          PUBLIC_URL = cfg.publicUrls.monograph;
        };
        healthCmd = ''bun -e "fetch('http://127.0.0.1:3000/api/health').then(r => { if (!r.ok) process.exit(1); }).catch(() => process.exit(1))"'';
      };
    }
    // lib.optionalAttrs ownsMongoDB {
      notesnook-mongodb = mkContainer {
        image = cfg.mongodb.owned.image;
        environmentFiles = [ ];
        volumes = [ "notesnook-mongodb:/data/db" ];
        exec = [
          "mongod"
          "--replSet"
          "rs0"
          "--bind_ip_all"
        ];
        healthCmd = ''echo 'try { rs.status() } catch (err) { rs.initiate() }; db.runCommand("ping").ok' | mongosh mongodb://localhost:27017 --quiet'';
      };
    }
    // lib.optionalAttrs ownsObjectStorage {
      notesnook-minio = mkContainer {
        image = cfg.objectStorage.owned.image;
        publishPorts = [ "${cfg.host}:${toString cfg.ports.attachments}:9000" ];
        volumes = [ "notesnook-minio:/data/s3" ];
        exec = [
          "server"
          "/data/s3"
          "--console-address"
          ":9090"
        ];
        healthCmd = "timeout 5s bash -c ':> /dev/tcp/127.0.0.1/9000' || exit 1";
      };

      notesnook-minio-setup = mkContainer {
        image = cfg.objectStorage.owned.setupImage;
        dependencies = [ "notesnook-minio" ];
        entrypoint = "/bin/sh";
        exec = [
          "-c"
          ''until mc alias set minio http://notesnook-minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"; do sleep 1; done; mc mb "minio/${cfg.objectStorage.bucket}" -p''
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          Restart = "on-failure";
        };
      };
    };

    systemd.services.notesnook-sync-server-environment = {
      description = "Prepare the Notesnook Sync Server runtime environment";
      documentation = [ "https://github.com/streetwriters/notesnook-sync-server#using-docker" ];
      wantedBy = [ "multi-user.target" ];
      before = containerUnits;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        EnvironmentFile = cfg.environmentFile;
        RuntimeDirectory = "notesnook-sync-server";
        RuntimeDirectoryMode = "0700";
        ExecStart = environmentSetup;
      };
    };
  };
}
