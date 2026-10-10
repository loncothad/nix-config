{
  virtualisation.quadlet.networks.selfhosted = {
    networkConfig = {
      name = "selfhosted";
      interfaceName = "selfhosted0";
    };
  };

  # Aardvark serves both transports, confined to the container bridge.
  networking.firewall.interfaces.selfhosted0 = {
    allowedTCPPorts = [ 53 ];
    allowedUDPPorts = [ 53 ];
  };
}
