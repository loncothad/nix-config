{ inputs, ... }:

let
  mkPackages = pkgs: {
    cargo-pretty = pkgs.callPackage ./package.nix {
      source = inputs.cargo-pretty-src;
    };
  };
in
{
  perSystem =
    { pkgs, ... }:
    let
      packages = mkPackages pkgs;
    in
    {
      packages = packages // {
        default = packages.cargo-pretty;
      };
    };

  flake.overlays.default = final: _prev: mkPackages final;
}
