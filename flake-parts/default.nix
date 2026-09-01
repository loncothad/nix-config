{ inputs, ... }:

{
  systems = [
    "x86_64-linux"
  ];

  imports = [
    inputs.treefmt.flakeModule
    inputs.fastpotify-adapter.flakeModules.default
    inputs.sub2api-adapter.flakeModules.default
    ./home-modules.nix
    ./treefmt.nix
    ./modules.nix
    ./packages.nix
    ./nixos-configurations.nix
  ];
}
