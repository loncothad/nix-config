{ pkgs, ... }:

{
  disko.devices = (import ../../../disko/configurations/kepler.nix).disko.devices;

  hardware.enableRedistributableFirmware = true;

  boot.zswap = {
    enable = true;
    zpool = "zsmalloc";
  };

  boot.kernelModules = [
    "intel_pstate"
    "ideapad_laptop"
  ];

  boot.initrd.kernelModules = [ "xe" ];
  boot.kernelParams = [
    "i915.force_probe=!e20b"
    "xe.force_probe=e20b"
    "i915.enable_psr=1"
    "xe.enable_display=1"
    "nvme_core.default_ps_max_latency=5500"
  ];

  hardware.firmware = with pkgs; [
    sof-firmware
    ivsc-firmware
  ];

  services.fwupd.enable = true;

  services.power-profiles-daemon.enable = true;
  services.thermald.enable = true;
  hardware.sensor.iio.enable = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-compute-runtime
      vpl-gpu-rt
      vulkan-loader
      vulkan-validation-layers
    ];
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="accel", KERNEL=="accel*", GROUP="video", MODE="0660"
  '';
}
