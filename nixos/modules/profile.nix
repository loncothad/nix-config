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

      formFactor = mkOption {
        type = types.enum [
          "laptop"
          "desktop"
          "generic"
        ];
        default = "desktop";
        description = ''
          Chassis used for sched_ext selection. Laptops run scx_rusty
          (domain locality + energy). Desktops run scx_bpfland (interactive
          vruntime). WSL ignores this and uses scx_rustyland.
        '';
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

        default_sched =
          if cfg.purpose == "wsl" then
            "scx_rustyland"
          else if cfg.hardware.formFactor == "laptop" then
            "scx_rusty"
          else
            "scx_bpfland";

        scheds = {
          # Laptop: keep work in LLC domains, prefer energy, steal only when
          # a remote queue actually has backlog. Hybrid Intel benefits from
          # local kthreads and letting the kernel place kworkers.
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
              "--tune-interval"
              "0.15"
              "--greedy-threshold"
              "2"
              "--direct-greedy-under"
              "70"
            ];
            gaming_mode = [
              "--perf"
              "1024"
              "--kthreads-local"
              "--balanced-kworkers"
              "--slice-us-underutil"
              "15000"
              "--slice-us-overutil"
              "1000"
              "--interval"
              "1.0"
              "--greedy-threshold"
              "1"
            ];
            lowlatency_mode = [
              "--perf"
              "1024"
              "--kthreads-local"
              "--balanced-kworkers"
              "--slice-us-underutil"
              "8000"
              "--slice-us-overutil"
              "500"
              "--interval"
              "1.0"
              "--tune-interval"
              "0.05"
              "--greedy-threshold"
              "1"
            ];
            powersave_mode = [
              "--perf"
              "0"
              "--kthreads-local"
              "--balanced-kworkers"
              "--slice-us-underutil"
              "40000"
              "--slice-us-overutil"
              "3000"
              "--interval"
              "4.0"
              "--greedy-threshold"
              "3"
              "--direct-greedy-under"
              "40"
            ];
            server_mode = [
              "--perf"
              "1024"
              "--balanced-kworkers"
              "--slice-us-underutil"
              "20000"
              "--slice-us-overutil"
              "2000"
              "--interval"
              "2.0"
              "--greedy-threshold"
              "1"
            ];
          };

          # Desktop: interactive vruntime, follow the power profile, scale
          # frequency, prefer faster idle cores. Modes match scx-loader/
          # CachyOS profiles with workstation extras.
          scx_bpfland = {
            auto_mode = [
              "-m"
              "auto"
              "-f"
              "-P"
            ];
            gaming_mode = [
              "-m"
              "all"
              "-f"
            ];
            lowlatency_mode = [
              "-m"
              "performance"
              "-w"
              "-P"
            ];
            powersave_mode = [
              "-s"
              "20000"
              "-m"
              "powersave"
              "-I"
              "100"
              "-t"
              "100"
            ];
            server_mode = [
              "-s"
              "20000"
              "-S"
              "-p"
            ];
          };
        };
      };
    };

    # Standard Environment Overrides
    networking.firewall.enable = mkDefault (cfg.purpose == "router" || cfg.network.isPublic);
  };
}
