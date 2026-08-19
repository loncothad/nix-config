{ ... }:

{
  systems = [
    "x86_64-linux"
  ];

  imports = [
    ./modules.nix
    ./packages.nix
    ./nixos-configurations.nix
  ];
}
