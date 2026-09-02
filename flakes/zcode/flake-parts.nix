{ inputs, ... }:

let
  mkPackages = pkgs: {
    coding-helper = pkgs.callPackage ./coding-helper.nix { };
    zcode = pkgs.callPackage ./zcode.nix { };
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
        default = packages.zcode;
      };
    };

  flake = {
    overlays.default = final: _prev: mkPackages final;

    homeModules.default =
      { lib, pkgs, ... }:
      {
        imports = [ ./home-manager.nix ];

        programs.zcode = {
          package = lib.mkDefault inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.zcode;
          codingHelperPackage =
            lib.mkDefault
              inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.coding-helper;
        };
      };
  };
}
