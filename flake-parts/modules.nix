{ ... }:

{
  flake = {
    nixosModules = {
      celld = ../nixos/modules/celld.nix;
      default = ../nixos/modules;
    };

    homeModules = {
      autolith = ../home-manager/modules/autolith.nix;
      default = ../home-manager/modules;
      fastpotify = ../home-manager/modules/fastpotify.nix;
      nushell-bom = ../home-manager/modules/nushell-bom.nix;
      polkit-agent-lxqt = ../home-manager/modules/polkit-agent-lxqt.nix;
      wayland-compatibility = ../home-manager/modules/wayland-compatibility.nix;
      xdg-dbus-proxy = ../home-manager/modules/xdg-dbus-proxy.nix;
    };
  };
}
