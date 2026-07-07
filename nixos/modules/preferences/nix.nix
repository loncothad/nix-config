{ inputs, pkgs, ... }:

# nh
# nixd
# nixfmt
# statix
# nix-output-monitor
# envfs
# nix-ld
# direnv

{
  options = {

  };

  config = {
    nix = {
      package = pkgs.lix;
      registry.s.flake = inputs.self;

      settings = {
        experimental-features = [
          "nix-command"
          "flakes"
          "auto-allocate-uids"
          "configurable-impure-env"
        ];
        trusted-users = [
          "root"
          "@wheel"
        ];
        auto-optimise-store = true;
        fallback = true;
        keep-outputs = true;
        keep-derivations = true;
        connect-timeout = 5;
        http-connections = 32;
        always-allow-substitutes = true;
        impure-env = [ "NIXPKGS_ALLOW_UNFREE" ];
        builders-use-substitutes = true;
      };
    };

    programs.nix-ld.enable = true;
  };
}
