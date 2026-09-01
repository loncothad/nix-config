{ inputs, ... }:

let
  mkPackages = pkgs: inputs.fastpotify-upstream.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  perSystem =
    { pkgs, ... }:
    {
      packages = mkPackages pkgs;
    };

  flake = {
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
