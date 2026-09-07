{ inputs, ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      packages = inputs.smolvm-upstream.packages.${pkgs.stdenv.hostPlatform.system};
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
    overlays.default = inputs.smolvm-upstream.overlays.default;
  };
}
