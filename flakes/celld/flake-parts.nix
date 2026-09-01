{ inputs, ... }:

let
  mkPackages = pkgs: {
    celld = pkgs.callPackage ./package.nix {
      source = inputs.celld-src;
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
        default = packages.celld;
      };
    };

  flake = {
    overlays.default = final: _prev: mkPackages final;

    nixosModules.default =
      { lib, pkgs, ... }:
      {
        imports = [ ./nixos.nix ];
        services.celld.package =
          lib.mkDefault
            inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.celld;
      };
  };
}
