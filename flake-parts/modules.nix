{ inputs, ... }:

{
  flake = {
    nixosModules = {
      celld = inputs.celld-adapter.nixosModules.default;
      ferron = ../nixos/modules/ferron.nix;
      notesnook-sync-server = inputs.notesnook-sync-server-adapter.nixosModules.default;
      sub2api = inputs.sub2api-adapter.nixosModules.default;
      default = {
        imports = [
          ../nixos/modules
          inputs.quadlet-nix.nixosModules.quadlet
          inputs.celld-adapter.nixosModules.default
          inputs.determinate.nixosModules.default
          inputs.notesnook-sync-server-adapter.nixosModules.default
          inputs.sub2api-adapter.nixosModules.default
        ];
      };
    };

    homeModules = {
      agents = ../home-manager/modules/agents.nix;
      autolith = ../home-manager/modules/autolith.nix;
      default = {
        imports = [
          ../home-manager/modules
          inputs.fastpotify-adapter.homeModules.default
        ];
      };
      mark-shot = ../home-manager/modules/mark-shot.nix;
      notesnook = ../home-manager/modules/notesnook.nix;
      nushell-bom = ../home-manager/modules/nushell-bom.nix;
      polkit-agent-lxqt = ../home-manager/modules/polkit-agent-lxqt.nix;
      wayland-compatibility = ../home-manager/modules/wayland-compatibility.nix;
      xdg-dbus-proxy = ../home-manager/modules/xdg-dbus-proxy.nix;
      xwayland-satellite = ../home-manager/modules/xwayland-satellite.nix;
      zellij-daemon = ../home-manager/modules/zellij-daemon.nix;
    };
  };
}
