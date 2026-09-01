{
  config,
  lib,
  ...
}:

let
  root = config.virtualisation.oci-containers.namedContainers;
  cfg = root.checkmate;
  runtime = config.virtualisation.quadlet;
  quadlet = config.virtualisation.quadlet;
  selfhostedNetwork = quadlet.networks.selfhosted.ref;
  ownsMongoDB = cfg.mongodb.mode == "owned";
  dependencies = lib.optional ownsMongoDB quadlet.containers."checkmate-mongodb".ref;
in
{
  options.virtualisation.oci-containers.namedContainers.checkmate = {
    enable = lib.mkEnableOption "Checkmate uptime monitor (documentation: https://checkmate.so/docs/getting-started/installation)";

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/bluewave-labs/checkmate:latest";
      description = "OCI image used for Checkmate.";
    };

    mongodb = {
      mode = lib.mkOption {
        type = lib.types.enum [
          "owned"
          "shared"
        ];
        default = "owned";
        description = "Whether Checkmate owns MongoDB or connects to a shared instance.";
      };

      owned.image = lib.mkOption {
        type = lib.types.str;
        default = "docker.io/library/mongo:8.0";
        description = "OCI image used for the owned MongoDB instance.";
      };

      shared.environmentFile = lib.mkOption {
        type = lib.types.path;
        description = ''
          Runtime environment file defining DB_CONNECTION_STRING for the
          shared MongoDB instance.
        '';
      };
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
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    virtualisation.quadlet.containers = {
      checkmate = {
        unitConfig = {
          Documentation = [ "https://checkmate.so/docs/getting-started/installation" ];
          Requires = dependencies;
          After = dependencies;
        };
        containerConfig = {
          image = cfg.image;
          publishPorts = [ "${cfg.host}:${toString cfg.port}:52345" ];
          networks = [ selfhostedNetwork ];
          environmentFiles = map toString (
            [ cfg.environmentFile ] ++ lib.optional (!ownsMongoDB) cfg.mongodb.shared.environmentFile
          );
          environments = {
            CLIENT_HOST = "http://${cfg.host}:${toString cfg.port}";
          }
          // lib.optionalAttrs ownsMongoDB {
            DB_CONNECTION_STRING = "mongodb://checkmate-mongodb:27017/uptime_db";
          }
          // cfg.environment;
          autoUpdate = if runtime.autoUpdate.enable then "registry" else null;
        };
      };
    }
    // lib.optionalAttrs ownsMongoDB {
      checkmate-mongodb = {
        unitConfig.Documentation = [ "https://checkmate.so/docs/getting-started/installation" ];
        containerConfig = {
          image = cfg.mongodb.owned.image;
          networks = [ selfhostedNetwork ];
          volumes = [ "checkmate-mongodb:/data/db" ];
          exec = [
            "mongod"
            "--quiet"
            "--bind_ip_all"
          ];
          autoUpdate = if runtime.autoUpdate.enable then "registry" else null;
        };
      };
    };
  };
}
