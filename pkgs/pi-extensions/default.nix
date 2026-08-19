{ lib, callPackage }:

let
  sources = lib.importJSON ./sources.json;
  buildPiNpmPackage = callPackage ./build-npm.nix { };

  built = lib.mapAttrs (
    name: src:
    buildPiNpmPackage {
      pname = name;
      inherit (src) version hash;
      npmName = src.npm;
      npmDepsHash = src.npmDepsHash or null;
    }
  ) sources;
in
built
// {
  inherit buildPiNpmPackage;
  sources = sources;
}
