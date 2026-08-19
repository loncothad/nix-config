{ ... }:

{
  flake = {
    nixosModules = {
      default = ../nixos/modules;
    };

    homeModules = {
      default = ../home-manager/modules;
      pi = ../home-manager/modules/pi.nix;
      xwayland-satellite = ../home-manager/modules/xwayland-satellite.nix;
      mark-shot = ../home-manager/modules/mark-shot.nix;
      nushell-bom = ../home-manager/modules/nushell-bom.nix;
      polkit-agent-lxqt = ../home-manager/modules/polkit-agent-lxqt.nix;
      wayland-compatibility = ../home-manager/modules/wayland-compatibility.nix;
    };
  };
}
