{ config, lib, ... }:
let
  cfg = config.boot.zswap;
  fixedAllocator = lib.versionAtLeast config.boot.kernelPackages.kernel.version "6.15";
in
{
  options.boot.kernelParams = lib.mkOption {
    apply =
      params:
      if cfg.enable && fixedAllocator then
        lib.filter (param: !(lib.hasPrefix "zswap.zpool=" param)) params
      else
        params;
  };

  config = lib.mkIf (cfg.enable && fixedAllocator) {
    boot.kernel.sysfs.module.zswap.parameters.zpool = lib.mkForce null;
    assertions = [
      {
        assertion = cfg.zpool == "zsmalloc";
        message = "Linux 6.15 and newer support only the zsmalloc Zswap allocator.";
      }
    ];
  };
}
