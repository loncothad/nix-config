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
        autolith = pkgs.fromFlakes.autolith.autolith;
        fastpotify = pkgs.fromFlakes.fastpotify.fastpotify;
        mark-shot = pkgs.fromFlakes.mark-shot.default;
        inherit (pkgs.fromFlakes.wine4office) wine4office wine4office-wine;
      };
    };
}
