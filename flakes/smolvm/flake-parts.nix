{ inputs, ... }:

let
  repairPackage = pkgs: upstreamPackage: pkgs.callPackage ./package.nix { inherit upstreamPackage; };
in
{
  perSystem =
    { pkgs, ... }:
    let
      upstreamPackages = inputs.smolvm-upstream.packages.${pkgs.stdenv.hostPlatform.system};
      smolvm = repairPackage pkgs upstreamPackages.smolvm;
    in
    {
      packages = upstreamPackages // {
        inherit smolvm;
        default = smolvm;
      };
    };

  flake = {
    flakeModules.default = { };

    nixosModules.default =
      { lib, pkgs, ... }:
      {
        imports = [ ./nixos.nix ];
        virtualisation.smolvm.package =
          lib.mkDefault
            inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.smolvm;
      };

    nixosModules.smolvm = inputs.self.nixosModules.default;
    overlays.default =
      final: prev:
      let
        upstream = inputs.smolvm-upstream.overlays.default final prev;
      in
      upstream // { smolvm = repairPackage final upstream.smolvm; };
  };
}
