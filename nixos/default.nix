{ inputs, ... }:

let
  latestRecognizedNixOsVersion = "26.05";

  overlaysModule = { ... }: {
    nixpkgs.overlays = [
      inputs.nix-cachyos-kernel.overlays.default
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

        overlaysModule
        
        inputs.disko.nixosModules.disko
        inputs.home-manager.nixosModules.home-manager
        inputs.nix-cachyos-kernel.nixosModules.default
        
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
      ../hosts/vega-small
    ];
  };
}
