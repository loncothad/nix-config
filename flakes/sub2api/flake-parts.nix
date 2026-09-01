{ inputs, ... }:

{
  flake.nixosModules.sub2api = {
    imports = [
      inputs.quadlet-nix.nixosModules.quadlet
      ./nixos.nix
    ];
  };
}
