{ inputs, ... }:

{
  systems = [
    "x86_64-linux"
  ];

  imports = [
    inputs.treefmt.flakeModule
    ./treefmt.nix
    ./modules.nix
    ./packages.nix
    ./nixos-configurations.nix
  ];
}
