{ inputs, ... }:

{
  systems = [
    "x86_64-linux"
  ];

  imports = [
    inputs.treefmt.flakeModule
    inputs.pi.flakeModules.default
    inputs.mark-shot-hm.flakeModules.default
    ./home-modules.nix
    ./treefmt.nix
    ./modules.nix
    ./packages.nix
    ./nixos-configurations.nix
  ];
}
