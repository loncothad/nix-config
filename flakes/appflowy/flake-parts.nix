{ inputs, ... }:

{
  flake.nixosModules.appflowy = {
    imports = [
      inputs.quadlet-nix.nixosModules.quadlet
      ./nixos.nix
    ];
  };
}
