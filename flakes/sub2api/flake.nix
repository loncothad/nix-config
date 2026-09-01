{
  description = "NixOS module for self-hosted Sub2API";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    quadlet-nix.url = "github:SEIAROTg/quadlet-nix";

    sub2api-src = {
      url = "github:Wei-Shaw/sub2api";
      flake = false;
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      imports = [
        ./flake-parts.nix
      ];

      flake = {
        flakeModules.default = ./flake-parts.nix;
        nixosModules.default = {
          imports = [
            inputs.quadlet-nix.nixosModules.quadlet
            ./nixos.nix
          ];
        };
      };
    };
}
