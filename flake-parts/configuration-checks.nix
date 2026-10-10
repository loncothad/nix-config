{ inputs, ... }:
{
  perSystem = { pkgs, ... }: {
    checks.configuration = import ../tests/configuration.nix { inherit inputs pkgs; };
    checks.zswap = import ../tests/zswap.nix { inherit inputs pkgs; };
    checks.apparmor = import ../tests/apparmor.nix { inherit inputs pkgs; };
  };
}
