{
  description = "NixOS module for self-hosted AppFlowy Cloud";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    appflowy-cloud-src = {
      url = "github:AppFlowy-IO/AppFlowy-Cloud";
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
        nixosModules.default = ./nixos.nix;
      };
    };
}
