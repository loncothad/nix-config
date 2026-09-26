{
  description = "cargo-pretty package adapter";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    cargo-pretty-src = {
      url = "github:romancitodev/cargo-pretty/bd6249e1f07c37b8ce98f8c99415321314db9355";
      flake = false;
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = [ ./flake-parts.nix ];
    };
}
