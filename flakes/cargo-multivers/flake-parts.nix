{ inputs, ... }:

let
  mkPackages = pkgs: {
    cargo-multivers = pkgs.callPackage ./package.nix {
      source = inputs.cargo-multivers-src;
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
        default = packages.cargo-multivers;
      };
    };

  flake.overlays.default = final: _prev: mkPackages final;
}
