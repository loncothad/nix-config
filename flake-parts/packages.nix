{ inputs, ... }:

{
  flake.overlays.default = import ../pkgs;

  perSystem =
    { system, lib, ... }:
    let
      pkgs = import inputs.nixpkgs { inherit system; };
    in
    {
      packages = lib.filterAttrs (_: lib.isDerivation) (
        pkgs.callPackage ../pkgs/pi-extensions { }
      );
    };
}
