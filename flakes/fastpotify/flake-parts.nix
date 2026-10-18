{ inputs, ... }:

let
  mkPackages =
    pkgs:
    let
      upstreamPackages = inputs.fastpotify-upstream.packages.${pkgs.stdenv.hostPlatform.system};
    in
    upstreamPackages
    // {
      fastpotify = upstreamPackages.spotifast;
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
