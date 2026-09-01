{
  config,
  lib,
  ...
}:

let
  root = config.virtualisation.oci-containers.namedContainers;
  cfg = root.homarr;
  runtime = config.virtualisation.quadlet;
  selfhostedNetwork = config.virtualisation.quadlet.networks.selfhosted.ref;
in
{
  options.virtualisation.oci-containers.namedContainers.homarr = {
    enable = lib.mkEnableOption "Homarr dashboard (documentation: https://homarr.dev/docs/getting-started/installation/docker/)";

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/homarr-labs/homarr:latest";
      description = "OCI image used for Homarr.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host address on which Homarr is published.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 7575;
      description = "Host port on which Homarr is published.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.path;
      example = "/run/agenix/homarr.env";
      description = "Secret environment file containing SECRET_ENCRYPTION_KEY.";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional non-secret environment variables for Homarr.";
    };

    dockerSocket = lib.mkEnableOption "access to the host Podman API socket";
    openFirewall = lib.mkEnableOption "the Homarr port in the firewall";
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    virtualisation.quadlet.containers.homarr = {
      unitConfig.Documentation = [ "https://homarr.dev/docs/getting-started/installation/docker/" ];
      containerConfig = {
        image = cfg.image;
        publishPorts = [ "${cfg.host}:${toString cfg.port}:7575" ];
        networks = [ selfhostedNetwork ];
        environmentFiles = [ (toString cfg.environmentFile) ];
        environments = cfg.environment;
        volumes = [
          "homarr-appdata:/appdata"
        ]
        ++ lib.optional cfg.dockerSocket "/run/podman/podman.sock:/var/run/docker.sock:ro";
        autoUpdate = if runtime.autoUpdate.enable then "registry" else null;
      };
    };

    virtualisation.podman.dockerSocket.enable = lib.mkIf cfg.dockerSocket true;
  };
}
