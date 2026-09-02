{ inputs, ... }:

let
  mkPackages = pkgs: {
    inherit (pkgs) codex;
    chatgpt = pkgs.callPackage ./chatgpt.nix { };
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
        default = packages.codex;
      };
    };

  flake = {
    overlays.default = final: _prev: mkPackages final;

    homeModules.default =
      { lib, pkgs, ... }:
      {
        imports = [ ./home-manager.nix ];

        programs.openai-codex = {
          package = lib.mkDefault inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.codex;
          desktopPackage = lib.mkDefault inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.chatgpt;
        };
      };
  };
}
