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
        celld = pkgs.fromFlakes.celld-adapter.celld;
        cargo-multivers = pkgs.fromFlakes.cargo-multivers-adapter.cargo-multivers;
        cargo-pretty = pkgs.fromFlakes.cargo-pretty-adapter.cargo-pretty;
        fastpotify = pkgs.fromFlakes.fastpotify-adapter.fastpotify;
        mark-shot = pkgs.fromFlakes.mark-shot.default;
        inherit (pkgs.fromFlakes.openai-codex-adapter) chatgpt codex;
        inherit (pkgs.fromFlakes.zcode-adapter) coding-helper zcode;
        zvec-grep = pkgs.fromFlakes.zvec-grep-adapter.zvec-grep;
        inherit (pkgs.fromFlakes.wine4office-adapter) wine4office wine4office-wine;
      };
    };
}
