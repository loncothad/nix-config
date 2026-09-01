{
  virtualisation.quadlet.networks.selfhosted = {
    networkConfig = {
      name = "selfhosted";
      interfaceName = "selfhosted0";
    };
  };

  networking.firewall.interfaces.selfhosted0.allowedUDPPorts = [ 53 ];
}
