{ inputs, ... }:

{
  systems = [
    "x86_64-linux"
  ];

  imports = [
    inputs.treefmt.flakeModule
    inputs.fastpotify-adapter.flakeModules.default
    inputs.notesnook-sync-server-adapter.flakeModules.default
    inputs.sub2api-adapter.flakeModules.default
    ./devshell.nix
    ./home-modules.nix
    ./treefmt.nix
    ./modules.nix
    ./packages.nix
    ./templates.nix
    ./nixos-configurations.nix
  ];
}
