{ inputs, ... }:

{
  flake = {
    nixosConfigurations = import ../nixos { inherit inputs; };

    diskoConfigurations = import ../disko;
  };
}
