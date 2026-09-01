{
  config,
  lib,
  ...
}:

let
  root = config.virtualisation.oci-containers.namedContainers;
  cfg = root.checkmate;
  runtime = root;
  updateLabels = lib.optionalAttrs runtime.autoUpdate.enable {
    "io.containers.autoupdate" = "registry";
  };
in
{
  options.virtualisation.oci-containers.namedContainers.checkmate = {
    enable = lib.mkEnableOption "Checkmate uptime monitor (documentation: https://checkmate.so/docs/getting-started/installation)";

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/bluewave-labs/checkmate:latest";
      description = "OCI image used for Checkmate.";
    };

    mongoImage = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/library/mongo:8.0";
      description = "OCI image used for Checkmate's MongoDB.";
    };

    mongodb.createLocally = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to run a dedicated MongoDB container. When false,
        environmentFile or environment must define DB_CONNECTION_STRING for a
        reusable external MongoDB instance.
      '';
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host address on which Checkmate is published.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 52345;
      description = "Host port on which Checkmate is published.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.path;
      example = "/run/agenix/checkmate.env";
      description = "Secret environment file containing at least JWT_SECRET.";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional non-secret environment variables for Checkmate.";
    };

    openFirewall = lib.mkEnableOption "the Checkmate port in the firewall";
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.namedContainers.enable = true;
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    virtualisation.oci-containers.containers = {
      checkmate = {
        image = cfg.image;
        ports = [ "${cfg.host}:${toString cfg.port}:52345" ];
        networks = [ "selfhosted" ];
        dependsOn = lib.optional cfg.mongodb.createLocally "checkmate-mongodb";
        environmentFiles = [ cfg.environmentFile ];
        environment = {
          CLIENT_HOST = "http://${cfg.host}:${toString cfg.port}";
        }
        // lib.optionalAttrs cfg.mongodb.createLocally {
          DB_CONNECTION_STRING = "mongodb://checkmate-mongodb:27017/uptime_db";
        }
        // cfg.environment;
        labels = updateLabels;
      };
    }
    // lib.optionalAttrs cfg.mongodb.createLocally {
      checkmate-mongodb = {
        image = cfg.mongoImage;
        networks = [ "selfhosted" ];
        volumes = [ "checkmate-mongodb:/data/db" ];
        cmd = [
          "mongod"
          "--quiet"
          "--bind_ip_all"
        ];
        labels = updateLabels;
      };
    };

    systemd.services = {
      podman-checkmate = {
        documentation = [ "https://checkmate.so/docs/getting-started/installation" ];
        after = [ "selfhosted-podman-network.service" ];
        requires = [ "selfhosted-podman-network.service" ];
      };
    }
    // lib.optionalAttrs cfg.mongodb.createLocally {
      podman-checkmate-mongodb = {
        documentation = [ "https://checkmate.so/docs/getting-started/installation" ];
        after = [ "selfhosted-podman-network.service" ];
        requires = [ "selfhosted-podman-network.service" ];
      };
    };
  };
}
