{ inputs, ... }:

{
  flake = {
    nixosModules = {
      celld = inputs.celld.nixosModules.default;
      default = {
        imports = [
          ../nixos/modules
          inputs.appflowy.nixosModules.default
          inputs.celld.nixosModules.default
        ];
      };
    };

    homeModules = {
      autolith = ../home-manager/modules/autolith.nix;
      default = ../home-manager/modules;
      fastpotify = inputs.fastpotify-adapter.homeModules.default;
      mark-shot = ../home-manager/modules/mark-shot.nix;
      nushell-bom = ../home-manager/modules/nushell-bom.nix;
      polkit-agent-lxqt = ../home-manager/modules/polkit-agent-lxqt.nix;
      wayland-compatibility = ../home-manager/modules/wayland-compatibility.nix;
      xdg-dbus-proxy = ../home-manager/modules/xdg-dbus-proxy.nix;
      xwayland-satellite = ../home-manager/modules/xwayland-satellite.nix;
    };
  };
}
