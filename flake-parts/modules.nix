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
      agents = ../home-manager/modules/agents;
      autolith = ../home-manager/modules/autolith.nix;
      openai-codex = inputs.openai-codex-adapter.homeModules.default;
      zcode = inputs.zcode-adapter.homeModules.default;
      default = {
        imports = [
          ../home-manager/modules
          inputs.fastpotify-adapter.homeModules.default
          inputs.openai-codex-adapter.homeModules.default
          inputs.zcode-adapter.homeModules.default
        ];
      };
      mark-shot = ../home-manager/modules/mark-shot.nix;
      mutable-config-files = ../home-manager/modules/mutable-config-files.nix;
      nushell-bom = ../home-manager/modules/nushell-bom.nix;
      polkit-agent-lxqt = ../home-manager/modules/polkit-agent-lxqt.nix;
      wayland-compatibility = ../home-manager/modules/wayland-compatibility.nix;
      xdg-dbus-proxy = ../home-manager/modules/xdg-dbus-proxy.nix;
      xdg-mime-apps = ../home-manager/modules/xdg-mime-apps.nix;
      xwayland-satellite = ../home-manager/modules/xwayland-satellite.nix;
      zellij-daemon = ../home-manager/modules/zellij-daemon.nix;
    };
  };
}
