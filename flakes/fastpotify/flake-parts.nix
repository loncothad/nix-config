{ inputs, ... }:

let
  mkPackages =
    pkgs:
    let
      upstreamPackages = inputs.fastpotify-upstream.packages.${pkgs.stdenv.hostPlatform.system};
      fastpotify = pkgs.callPackage ./package.nix {
        upstreamPackage = upstreamPackages.fastpotify;
        upstreamSource = inputs.fastpotify-upstream;
      };
    in
    upstreamPackages
    // {
      default = fastpotify;
      inherit fastpotify;
    };
in
{
  perSystem =
    { pkgs, ... }:
    {
      packages = mkPackages pkgs;
    };

  flake = {
    flakeModules.default = {
      flake.homeModules.fastpotify = inputs.self.homeModules.default;
    };

    overlays.default = final: _prev: mkPackages final;

    homeModules.default =
      { lib, pkgs, ... }:
      {
        imports = [ ./home-manager.nix ];
        programs.fastpotify.package =
          lib.mkDefault
            inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.fastpotify;
      };
  };
}
