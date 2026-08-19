{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.host.profile;
in
{
  options.host.profile = {
    enable = mkEnableOption "host optimization profiling configuration";

    purpose = mkOption {
      type = types.enum [
        "desktop"
        "server"
        "router"
        "relay"
        "wsl"
        "development"
      ];
      default = "desktop";
      description = "The primary runtime purpose and form factor of the host.";
    };

    platform = mkOption {
      type = types.enum [
        "nixos"
        "darwin"
        "generic-linux"
      ];
      default = "nixos";
      description = "The underlying operating system/configuration framework.";
    };

    network = {
      isPublic = mkOption {
        type = types.bool;
        default = false;
        description = "Whether this host is directly exposed to the public internet.";
      };

      roles = mkOption {
        type = types.listOf (
          types.enum [
            "radicle-node"
            "none"
          ]
        );
        default = [ "none" ];
        description = "Specific network-level primitive roles this host executes.";
      };
    };

    hardware = {
      isVirtual = mkOption {
        type = types.bool;
        default = false;
        description = "Flag for cloud instances, VMs, or containers.";
      };

      hasNvidiaGPU = mkOption {
        type = types.bool;
        default = false;
        description = "Determines whether to inject proprietary graphics pipelines.";
      };

      # New Options Added Below
      cpuArchitecture = mkOption {
        type = types.enum [
          "generic"
          "v3"
          "v4"
        ];
        default = "v3";
        description = "Target micro-architecture level for kernel and low-level system binaries.";
      };

      schedExtMode = mkOption {
        type = types.enum [
          "auto"
          "forced"
          "disabled"
        ];
        default = "auto";
        description = "Controls user-space extensible scheduler integration.";
      };
    };
  };

  config = mkIf cfg.enable {
    # Core Host Logic Validations
    assertions = [
      {
        assertion = (cfg.purpose == "wsl") -> (cfg.platform == "nixos");
        message = "WSL hosts must use the nixos platform.";
      }
      {
        assertion = (cfg.purpose == "router") -> (cfg.platform != "darwin");
        message = "Darwin cannot be configured as a primary network router.";
      }
    ];

    # =========================================================================
    # Best-Effort Kernel Target Selection
    # =========================================================================
    boot.kernelPackages = mkIf (cfg.platform == "nixos") (
      let
        # Map our hardware.cpuArchitecture to the correct CachyOS overlay binary tier
        cachyTier =
          if cfg.hardware.cpuArchitecture == "v4" then
            pkgs.cachyosKernels.linuxPackages-cachyos-bore-lto-x86_64-v4
          else if cfg.hardware.cpuArchitecture == "v3" then
            pkgs.cachyosKernels.linuxPackages-cachyos-bore-lto-x86_64-v3
          else
            pkgs.cachyosKernels.linuxPackages-cachyos-latest-lto-x86_64-v3;
      in
      # Core Infrastructure Rules:
      # Servers & Routers require EEVDF stock execution streams for throughput.
      # Desktops and Development machines get optimized low-latency sched-ext stacks.
      if
        builtins.elem cfg.purpose [
          "server"
          "router"
          "relay"
        ]
      then
        pkgs.cachyosKernels.linuxPackages-cachyos-latest-lto-x86_64-v3
      else
        cachyTier
    );

    # =========================================================================
    # Best-Effort sched_ext Execution Configuration
    # =========================================================================
    services.scx-loader = mkIf (cfg.platform == "nixos" && cfg.hardware.schedExtMode != "disabled") {
      # Automatically activate if running a compatible client environment
      enable = mkDefault (
        cfg.hardware.schedExtMode == "forced"
        || builtins.elem cfg.purpose [
          "desktop"
          "development"
          "wsl"
        ]
      );

      config = {
        default_mode = "Auto";

        # Match workloads precisely against form factor attributes
        default_sched =
          if cfg.purpose == "wsl" then
            "scx_rustyland"
          else if cfg.purpose == "desktop" then
            "scx_rusty"
          else
            "scx_bpfland";

        scheds = {
          # Laptop: energy-biased CPU freq, keep kthreads local, steal only
          # when a remote queue actually has work, load-balance less often.
          scx_rusty = {
            auto_mode = [
              "--perf"
              "0"
              "--kthreads-local"
              "--balanced-kworkers"
              "--slice-us-underutil"
              "30000"
              "--slice-us-overutil"
              "2000"
              "--interval"
              "3.0"
              "--greedy-threshold"
              "2"
            ];
            gaming_mode = [
              "--perf"
              "1024"
              "--kthreads-local"
              "--balanced-kworkers"
            ];
          };
          scx_bpfland = {
            auto_mode = [
              "-m"
              "performance"
              "-w"
            ];
          };
        };
      };
    };

    # Standard Environment Overrides
    networking.firewall.enable = mkDefault (cfg.purpose == "router" || cfg.network.isPublic);
  };
}
