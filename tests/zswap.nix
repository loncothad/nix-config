{ inputs, pkgs }:
let
  inherit (pkgs) lib;
  evaluate =
    extra:
    (inputs.nixpkgs.lib.nixosSystem {
      system = pkgs.stdenv.hostPlatform.system;
      modules = [
        ../nixos/modules/zswap-compat.nix
        {
          boot.loader.grub.enable = false;
          fileSystems."/" = {
            device = "/dev/test";
            fsType = "ext4";
          };
          system.stateVersion = "26.05";
          boot.kernelParams = [ "audit-unrelated=keep" ];
        }
        extra
      ];
    }).config;
  current = evaluate { boot.zswap.enable = true; };
  older = evaluate {
    boot.kernelPackages = pkgs.linuxPackages_6_12;
    boot.zswap = {
      enable = true;
      zpool = "zbud";
    };
  };
  disabled = evaluate { };
  rejected = evaluate {
    boot.zswap = {
      enable = true;
      zpool = "zbud";
    };
  };
in
assert lib.versionAtLeast current.boot.kernelPackages.kernel.version "6.15";
assert !(lib.any (lib.hasPrefix "zswap.zpool=") current.boot.kernelParams);
assert current.boot.kernel.sysfs.module.zswap.parameters.zpool == null;
assert lib.elem "zswap.enabled=1" current.boot.kernelParams;
assert lib.elem "audit-unrelated=keep" current.boot.kernelParams;
assert lib.elem "zswap.zpool=zbud" older.boot.kernelParams;
assert older.boot.kernel.sysfs.module.zswap.parameters.zpool == "zbud";
assert !(lib.any (lib.hasPrefix "zswap.") disabled.boot.kernelParams);
assert !(builtins.tryEval rejected.system.build.toplevel.drvPath).success;
pkgs.runCommand "zswap-configuration-checks" { } ''
  mkdir -p $out
  printf '%s\n' ${lib.escapeShellArgs current.boot.kernelParams} > $out/current-kernel-params
  printf '%s\n' ${lib.escapeShellArgs older.boot.kernelParams} > $out/older-kernel-params
''
