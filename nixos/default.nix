{ inputs, ... }:

let
  latestRecognizedNixOsVersion = "26.05";

  overlaysModule = { ... }: {
    nixpkgs.overlays = [
      inputs.nix-cachyos-kernel.overlays.default
      (import ../pkgs { inherit inputs; })
    ];
  };

  mkNixOsSystem =
    {
      system,
      extraArgs ? { },
      extraModules ? [ ],
    }:
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;

      specialArgs = {
        inherit inputs;
      }
      // extraArgs;

      modules = [
        ./modules
        ./modules/user-profiles/by-name/loncothad.nix

        overlaysModule

        inputs.celld-adapter.nixosModules.default
        inputs.sub2api-adapter.nixosModules.default
        inputs.determinate.nixosModules.default
        inputs.disko.nixosModules.disko
        inputs.home-manager.nixosModules.home-manager
        inputs.quadlet-nix.nixosModules.quadlet

        ({ ... }: { system.stateVersion = latestRecognizedNixOsVersion; })
      ]
      ++ extraModules;
    };
in
{
  kepler = mkNixOsSystem {
    system = "x86_64-linux";
    extraModules = [
      ./hosts/kepler
    ];
  };

  vega-small = mkNixOsSystem {
    system = "x86_64-linux";
    extraModules = [
      ./hosts/vega-small
    ];
  };
}
