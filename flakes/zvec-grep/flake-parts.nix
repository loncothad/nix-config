{ inputs, ... }:

let
  mkPackages = pkgs: {
    zvec-grep = pkgs.callPackage ./package.nix {
      source = inputs.zvec-grep-src;
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
        default = packages.zvec-grep;
      };
    };

  flake.overlays.default = final: _prev: mkPackages final;
}
