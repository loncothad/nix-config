{
  config,
  lib,
  ...
}:

let
  root = config.virtualisation.oci-containers.namedContainers;
  cfg = root.homarr;
  runtime = root;
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
    virtualisation.oci-containers.namedContainers.enable = true;
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    virtualisation.oci-containers.containers.homarr = {
      image = cfg.image;
      ports = [ "${cfg.host}:${toString cfg.port}:7575" ];
      networks = [ "selfhosted" ];
      environmentFiles = [ cfg.environmentFile ];
      environment = cfg.environment;
      volumes = [
        "homarr-appdata:/appdata"
      ]
      ++ lib.optional cfg.dockerSocket "/run/podman/podman.sock:/var/run/docker.sock:ro";
      labels = lib.optionalAttrs runtime.autoUpdate.enable {
        "io.containers.autoupdate" = "registry";
      };
    };

    virtualisation.podman.dockerSocket.enable = lib.mkIf cfg.dockerSocket true;

    systemd.services.podman-homarr = {
      documentation = [ "https://homarr.dev/docs/getting-started/installation/docker/" ];
      after = [ "selfhosted-podman-network.service" ];
      requires = [ "selfhosted-podman-network.service" ];
    };
  };
}
