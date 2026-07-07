{ config, lib, ... }:

with lib;

let
  cfg = config.networking.optimizations;
in
{
  options = {
    networking.optimizations = {
      enable = mkEnableOption "high-performance system-wide network optimizations";

      core = mkOption {
        type = types.bool;
        default = cfg.enable;
        description = "Core network stack queue configurations and NAPI polling intervals for high-throughput interface bursts.";
      };

      buffers = mkOption {
        type = types.bool;
        default = cfg.enable;
        description = "Global and socket-specific memory vector allocations for maximum window scaling across high-bandwidth paths.";
      };

      tcp = mkOption {
        type = types.bool;
        default = cfg.enable;
        description = "TCP state transport tuning, BBR congestion pacing, and mitigation of user-space bufferbloat.";
      };

      udp = mkOption {
        type = types.bool;
        default = cfg.enable;
        description = "UDP memory management optimizations, targeting high-volume stateless ingestion protocols like QUIC/HTTP3.";
      };

      ipv6 = mkOption {
        type = types.bool;
        default = cfg.enable;
        description = "IPv6 protocol stack tuning, expanded routing table scales, and secure router advertisement constraints.";
      };

      conntrack = mkOption {
        type = types.bool;
        default = cfg.enable;
        description = "Netfilter connection tracking table scaling and aggressive state machine garbage collection pruning.";
      };

      security = mkOption {
        type = types.bool;
        default = cfg.enable;
        description = "Network-layer structural protection including reverse path validation (RPF) and specific TCP segment exploit mitigation.";
      };
    };
  };

  config = mkIf cfg.enable {
    boot.kernelModules = mkMerge [
      (mkIf cfg.tcp [
        "tcp_bbr"
        "tls"
      ])
    ];

    boot.kernel.sysctl = mkMerge [
      (mkIf cfg.core {
        # "net.core.default_qdisc" = "cake";
        "net.core.somaxconn" = 8192;
        "net.core.optmem_max" = 65536;
        "net.core.netdev_max_backlog" = 16384; # Max packets queued on the input side if an interface receives packets faster than the kernel can process them
        "net.core.dev_weight" = 64; # Max packets processed by the kernel in a single NAPI polling cycle
        "net.core.netdev_budget" = 600; # Total max packets processed by all interfaces in a single execution of net_rx_action
      })

      (mkIf cfg.buffers {
        "net.core.rmem_default" = 1048576;
        "net.core.rmem_max" = 33554432;
        "net.core.wmem_default" = 1048576;
        "net.core.wmem_max" = 33554432;
        "net.ipv4.tcp_rmem" = "4096 1048576 33554432";
        "net.ipv4.tcp_wmem" = "4096 65536 33554432";

        # System-wide global TCP memory tracking (min, pressure, max in 4KB architecture pages)
        # Allows up to ~16GB overall allocation under pressure before enforcing constraints
        "net.ipv4.tcp_mem" = "1048576 2097152 4194304";
      })

      (mkIf cfg.tcp {
        "net.ipv4.tcp_congestion_control" = "bbr";
        "net.ipv4.tcp_fastopen" = 3;
        "net.ipv4.tcp_max_syn_backlog" = 8192;
        "net.ipv4.tcp_max_tw_buckets" = 2000000;
        "net.ipv4.tcp_mtu_probing" = 1;
        "net.ipv4.tcp_slow_start_after_idle" = 0;
        "net.ipv4.tcp_tw_reuse" = 1;
        "net.ipv4.tcp_fin_timeout" = 15;
        "net.ipv4.tcp_ecn" = 1;
        "net.ipv4.tcp_window_scaling" = 1;

        # Bufferbloat mitigation: controls the amount of unsent data allowed in the socket write queue.
        # Essential for maintaining low latency on multiplexed connections (HTTP/2, HTTP/3, TLS).
        "net.ipv4.tcp_notsent_lowat" = 16384;

        # Proactively optimize localized payload packaging
        "net.ipv4.tcp_autocorking" = 1;
      })

      (mkIf cfg.udp {
        "net.ipv4.udp_rmem_min" = 8192;
        "net.ipv4.udp_wmem_min" = 8192;

        # System-wide global UDP memory tracking (min, pressure, max in 4KB pages)
        # Prevents high-pps UDP infrastructure (e.g., WireGuard, QUIC data planes) from starvations
        "net.ipv4.udp_mem" = "524288 1048576 2097152";
      })

      (mkIf cfg.ipv6 {
        # Increase the maximum number of IPv6 routes allowed in the routing table cache
        "net.ipv6.route.max_size" = 409600;

        # Drop ICMPv6 redirect packets from non-gateway origins to stop routing topology manipulation
        "net.ipv6.conf.all.accept_redirects" = 0;
        "net.ipv6.conf.default.accept_redirects" = 0;

        # Enable hop limits adjustments and Router Advertisements where explicitly allowed via network managers safely
        "net.ipv6.conf.all.accept_ra" = 1;
        "net.ipv6.conf.default.accept_ra" = 1;
      })

      (mkIf cfg.conntrack {
        "net.netfilter.nf_conntrack_generic_timeout" = 60;
        "net.netfilter.nf_conntrack_max" = 1048576;
        "net.netfilter.nf_conntrack_tcp_timeout_established" = 600;
        "net.netfilter.nf_conntrack_tcp_timeout_time_wait" = 1;
      })

      (mkIf cfg.security {
        "net.ipv4.conf.all.log_martians" = 1;
        "net.ipv4.conf.all.rp_filter" = 1;
        "net.ipv4.conf.default.log_martians" = 1;
        "net.ipv4.conf.default.rp_filter" = 1;
        "net.ipv4.tcp_rfc1337" = 1;
        "net.ipv4.tcp_syncookies" = 1;

        # Parity structures mapping protection logic directly into the IPv6 interfaces
        "net.ipv6.conf.all.log_martians" = 1;
        "net.ipv6.conf.default.log_martians" = 1;
        # Note: Linux kernel implements IPv6 source validation differently via netfilter/rp_filter hooks,
        # but modern kernels support standard configuration parity switches:
        "net.ipv6.conf.all.rp_filter" = 1;
        "net.ipv6.conf.default.rp_filter" = 1;
      })
    ];
  };
}
