{
  config,
  lib,
  ...
}:

let
  root = config.virtualisation.oci-containers.namedContainers;
  cfg = root.omni-tools;
  runtime = root;
in
{
  options.virtualisation.oci-containers.namedContainers.omni-tools = {
    enable = lib.mkEnableOption "OmniTools web application";

    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/iib0011/omni-tools:latest";
      description = "OCI image used for OmniTools.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host address on which OmniTools is published.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Host port on which OmniTools is published.";
    };

    openFirewall = lib.mkEnableOption "the OmniTools port in the firewall";
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.namedContainers.enable = true;
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    virtualisation.oci-containers.containers.omni-tools = {
      image = cfg.image;
      ports = [ "${cfg.host}:${toString cfg.port}:80" ];
      networks = [ "selfhosted" ];
      labels = lib.optionalAttrs runtime.autoUpdate.enable {
        "io.containers.autoupdate" = "registry";
      };
    };

    systemd.services.podman-omni-tools = {
      after = [ "selfhosted-podman-network.service" ];
      requires = [ "selfhosted-podman-network.service" ];
    };
  };
}
