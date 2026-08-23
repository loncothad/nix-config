{ inputs, ... }:

let
  mkPackages =
    pkgs:
    let
      wine4officeWine = pkgs.callPackage ./wine.nix {
        src = inputs.wine4office-src;
      };
      wine4office = pkgs.callPackage ./package.nix {
        src = inputs.wine4office-src;
        wine = wine4officeWine;
      };
    in
    {
      inherit wine4office;
      wine4office-wine = wine4officeWine;
    };
in
{
  perSystem =
    {
      lib,
      pkgs,
      ...
    }:
    let
      packages = mkPackages pkgs;
    in
    {
      packages = packages // {
        default = packages.wine4office;
      };

      apps.default = {
        type = "app";
        program = lib.getExe packages.wine4office;
        meta.description = packages.wine4office.meta.description;
      };
    };

  flake.overlays.default = final: _prev: mkPackages final;
}
