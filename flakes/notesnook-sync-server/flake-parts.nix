{ inputs, ... }:

{
  flake.nixosModules.notesnook-sync-server = {
    imports = [
      inputs.quadlet-nix.nixosModules.quadlet
      ./nixos.nix
    ];
  };
}
