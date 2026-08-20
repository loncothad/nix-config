{ ... }:

{
  flake = {
    nixosModules = {
      default = ../nixos/modules;
    };

    homeModules = {
      default = ../home-manager/modules;
      xwayland-satellite = ../home-manager/modules/xwayland-satellite.nix;
      nushell-bom = ../home-manager/modules/nushell-bom.nix;
      polkit-agent-lxqt = ../home-manager/modules/polkit-agent-lxqt.nix;
      wayland-compatibility = ../home-manager/modules/wayland-compatibility.nix;
    };
  };
}
