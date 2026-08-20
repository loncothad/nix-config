{
  config,
  lib,
  ...
}:

let
  cfg = config.services.homarr;
  runtime = config.services.selfhosted.containers;
in
{
  options.services.homarr = {
    enable = lib.mkEnableOption "Homarr dashboard";

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

    dockerSocket = lib.mkEnableOption "access to the host Podman API socket";
    openFirewall = lib.mkEnableOption "the Homarr port in the firewall";
  };

  config = lib.mkIf cfg.enable {
    services.selfhosted.containers.enable = true;
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    virtualisation.oci-containers.containers.homarr = {
      image = cfg.image;
      ports = [ "${cfg.host}:${toString cfg.port}:7575" ];
      networks = [ "selfhosted" ];
      environmentFiles = [ cfg.environmentFile ];
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
      after = [ "selfhosted-podman-network.service" ];
      requires = [ "selfhosted-podman-network.service" ];
    };
  };
}
