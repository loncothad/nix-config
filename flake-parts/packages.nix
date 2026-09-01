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
        autolith = pkgs.fromFlakes.autolith.autolith;
        celld = pkgs.fromFlakes.celld.celld;
        fastpotify = pkgs.fromFlakes.fastpotify-adapter.fastpotify;
        mark-shot = pkgs.fromFlakes.mark-shot.default;
        inherit (pkgs.fromFlakes.wine4office) wine4office wine4office-wine;
      };
    };
}
