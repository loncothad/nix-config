{ config, lib, pkgs, ... }:

let
  cfg = config.virtualisation.smolvm;
  shimPackage = pkgs.runCommand "containerd-shim-smolvm-v2" { } ''
    test -x ${cfg.package}/libexec/smolvm/containerd-shim-smolvm-v2
    mkdir -p $out/bin
    ln -s ${cfg.package}/libexec/smolvm/containerd-shim-smolvm-v2 \
      $out/bin/containerd-shim-smolvm-v2
  '';
in
{
  options.virtualisation.smolvm = {
    enable = lib.mkEnableOption "the smolvm OCI microVM runtime";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The smolvm package providing the OCI engine and containerd shim.";
    };

    dataDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/smolvm";
      description = "State directory used by smolvm and its containerd shim.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.isLinux;
        message = "virtualisation.smolvm requires a Linux host with KVM support.";
      }
    ];

    environment.systemPackages = [
      cfg.package
      shimPackage
    ];

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDirectory} 0755 root root -"
    ];

    systemd.services.containerd = {
      environment = {
        SMOLVM_DATA_DIR = cfg.dataDirectory;
        SMOLVM_AGENT_ROOTFS = "${cfg.package}/libexec/smolvm/agent-rootfs";
        SMOLVM_BOOT_BINARY = "${cfg.package}/libexec/smolvm/smolvm-bin";
        SMOLVM_LIB_DIR = "${cfg.package}/libexec/smolvm/lib";
      };
      path = [
        cfg.package
        shimPackage
      ];
    };

    virtualisation.containerd = {
      enable = true;
      settings.plugins."io.containerd.grpc.v1.cri".containerd.runtimes.smolvm = {
        runtime_type = "io.containerd.smolvm.v2";
      };
    };
  };
}
