{ inputs, ... }:

{
  systems = [
    "x86_64-linux"
  ];

  imports = [
    inputs.treefmt.flakeModule
    inputs.appflowy.flakeModules.default
    inputs.xwayland-satellite.flakeModules.default
    ./home-modules.nix
    ./treefmt.nix
    ./modules.nix
    ./packages.nix
    ./nixos-configurations.nix
  ];
}
