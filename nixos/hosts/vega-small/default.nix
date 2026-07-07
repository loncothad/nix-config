{ inputs, ... }:

{
  imports = [
    inputs.nixos-wsl.nixosModules.default
  ];

  networking.hostName = "vega-small";

  wsl = {
    enable = true;
    defaultUser = "loncothad";
  };

  host.profile = {
    enable = true;
    purpose = "wsl";
    platform = "nixos";
    hardware.cpuArchitecture = "v3";
  };

  preferences.core = {
    enable = true;
    timeZone = "Europe/Moscow";
  };

  # preferences.agenix = {
  #   enable = true;
  #   masterKeys = [

  #   ];
  # };

  users.profiles.loncothad = {
    enable = true;
  };
  users.users.loncothad.initialHashedPassword = "$y$j9T$aw8Yt7xsjcLgek9ZrZZNH1$NXEMoBYOyuvDSxyd8zBZriJyN7PrepEtUkcPHJRWVq7";

  age.secrets.loncothad-password = {
    rekeyFile = ../../../../secrets/loncothad-password.age;
  };

  preferences.home-manager.enable = true;
}
