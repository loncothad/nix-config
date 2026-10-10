{
  inputs,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./scheduler.nix
    inputs.nixos-wsl.nixosModules.default
  ];

  networking.hostName = "vega-small";

  wsl = {
    enable = true;
    defaultUser = "loncothad";
  };

  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-bore-lto-x86_64-v3;

  preferences.core = {
    enable = true;
    timeZone = "Europe/Moscow";
  };

  # WSL synchronizes the guest clock from Windows and disables timesyncd.
  preferences.networking.time.enable = false;
  systemd.oomd.enable = lib.mkForce false;

  # preferences.agenix = {
  #   enable = true;
  #   masterKeys = [

  #   ];
  # };

  users.profiles.loncothad = {
    enable = true;
  };
  users.users.loncothad.initialHashedPassword = "$y$j9T$aw8Yt7xsjcLgek9ZrZZNH1$NXEMoBYOyuvDSxyd8zBZriJyN7PrepEtUkcPHJRWVq7";

  preferences.home-manager.enable = true;
}
