{ inputs, ... }:
{
  perSystem = { pkgs, ... }: {
    checks.networking = import ../tests/networking.nix { inherit inputs pkgs; };
    checks.zswap = import ../tests/zswap.nix { inherit inputs pkgs; };
    packages.networking-compare = pkgs.writeShellApplication {
      name = "networking-compare";
      runtimeInputs = [ pkgs.python3 ];
      text = ''exec python3 ${../tests/resolver-compare.py} "$@"'';
    };
    packages.networking-vm-test = import ../tests/networking-vm.nix { inherit inputs pkgs; };
  };
}
