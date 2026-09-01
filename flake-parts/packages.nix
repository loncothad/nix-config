{ inputs, ... }:

{
  flake.overlays.default = import ../pkgs { inherit inputs; };

  perSystem =
    { system, ... }:
    let
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [ (import ../pkgs { inherit inputs; }) ];
      };
    in
    {
      packages = {
        inherit (pkgs) celld;
        inherit (pkgs.fromFlakes)
          autolith
          fastpotify
          mark-shot
          wine4office
          wine4office-wine;
      };
    };
}
