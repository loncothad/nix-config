{ config, lib, ... }:
{
  options.networking.optimizations.enable = lib.mkEnableOption "BBR congestion control and CAKE queuing";

  config = lib.mkIf config.networking.optimizations.enable {
    boot.kernelModules = [ "tcp_bbr" ];
    boot.kernel.sysctl = {
      "net.core.default_qdisc" = "cake";
      "net.ipv4.tcp_congestion_control" = "bbr";
      # Probe a smaller MTU only after a suspected PMTU black hole (VPNs).
      "net.ipv4.tcp_mtu_probing" = 1;
    };
    # Let the kernel size memory/conntrack tables and keep its established
    # connection lifetime. Fixed page thresholds scaled poorly across hosts;
    # a 10-minute conntrack timeout breaks idle SSH/VPN connections through NAT.
  };
}
