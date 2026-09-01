{
  config,
  lib,
  ...
}:

let
  root = config.virtualisation.oci-containers.namedContainers;
  cfg = root.omni-tools;
  runtime = config.virtualisation.quadlet;
  selfhostedNetwork = config.virtualisation.quadlet.networks.selfhosted.ref;
in
{
  options.virtualisation.oci-containers.namedContainers.omni-tools = {
    enable = lib.mkEnableOption "OmniTools web application (documentation: https://github.com/iib0011/omni-tools#readme)";

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
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    virtualisation.quadlet.containers.omni-tools = {
      unitConfig.Documentation = [ "https://github.com/iib0011/omni-tools#readme" ];
      containerConfig = {
        image = cfg.image;
        publishPorts = [ "${cfg.host}:${toString cfg.port}:80" ];
        networks = [ selfhostedNetwork ];
        autoUpdate = if runtime.autoUpdate.enable then "registry" else null;
      };
    };
  };
}
