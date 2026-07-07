{
  lib,
  config,
  ...
}:

let
  cfg = config.preferences.networking;
  inherit (lib)
    mkIf
    mkMerge
    mkOption
    types
    optionalString
    concatMapStringsSep
    ;

  # Format helpers for nftables
  toNftSet = items: "{ ${concatMapStringsSep ", " toString items} }";
  toNftIfaceSet = ifaces: "{ ${concatMapStringsSep ", " (i: ''"${i}"'') ifaces} }";
  toNftSubnetSet = subnets: "{ ${concatMapStringsSep ", " toString subnets} }";
in
{
  options.preferences.networking = {
    routing = {
      enableForwarding = mkOption {
        type = types.bool;
        default = false;
        description = "Enable kernel-level IPv4 and IPv6 packet forwarding (Router capability).";
      };
    };

    dns = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Manage system-wide DNS architecture and encryption wrappers.";
      };
      mode = mkOption {
        type = types.enum [
          "plain"
          "dot"
          "doh"
        ];
        default = "dot";
        description = "Encryption architecture for outgoing DNS queries.";
      };
      upstreamServers = mkOption {
        type = types.listOf types.str;
        default = [
          "1.1.1.1#cloudflare-dns.com"
          "9.9.9.9#dns.quad9.net"
        ];
        description = "Upstream recursive resolvers.";
      };
      dnssec = mkOption {
        type = types.enum [
          "true"
          "false"
          "allow-downgrade"
        ];
        default = "allow-downgrade";
        description = "Enforce DNSSEC validation state.";
      };
    };

    time = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable and configure system time synchronization (NTP).";
      };
      mode = mkOption {
        type = types.enum [
          "client"
          "server"
        ];
        default = "client";
        description = ''
          NTP operational topology:
          - 'client': Employs lightweight systemd-timesyncd for local clock alignment.
          - 'server': Employs chrony to act as a high-precision NTP server for downstream peers.
        '';
      };
      servers = mkOption {
        type = types.listOf types.str;
        default = [
          "time.google.com"
          "time.cloudflare.com"
          "0.nixos.pool.ntp.org"
          "1.nixos.pool.ntp.org"
          "2.nixos.pool.ntp.org"
        ];
        description = "List of upstream NTP stratums to track.";
      };
      allowedClients = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Subnets/IPs permitted to poll this machine for time (Server mode only).";
      };
    };

    firewall = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable native nftables-based firewall.";
      };
      allowedTcpPorts = mkOption {
        type = types.listOf types.port;
        default = [ ];
      };
      allowedUdpPorts = mkOption {
        type = types.listOf types.port;
        default = [ ];
      };
      trustedInterfaces = mkOption {
        type = types.listOf types.str;
        default = [ ];
      };
      allowLocalDiscovery = mkOption {
        type = types.bool;
        default = false;
      };
      rateLimitSsh = {
        enable = mkOption {
          type = types.bool;
          default = false;
        };
        maxConnections = mkOption {
          type = types.int;
          default = 5;
        };
      };
      nat = {
        enable = mkOption {
          type = types.bool;
          default = false;
        };
        externalInterface = mkOption {
          type = types.nullOr types.str;
          default = null;
        };
        internalInterfaces = mkOption {
          type = types.listOf types.str;
          default = [ ];
        };
      };
      extraInputRules = mkOption {
        type = types.lines;
        default = "";
      };
      extraForwardRules = mkOption {
        type = types.lines;
        default = "";
      };
    };
  };

  config = mkMerge [
    # Routing Forwarding Sysctls
    (mkIf cfg.routing.enableForwarding {
      boot.kernel.sysctl = {
        "net.ipv4.ip_forward" = 1;
        "net.ipv6.conf.all.forwarding" = 1;
      };
    })

    # DNS Config
    (mkIf (cfg.dns.enable && cfg.dns.mode == "plain") {
      networking.nameservers = cfg.dns.upstreamServers;
    })

    (mkIf (cfg.dns.enable && cfg.dns.mode == "dot") {
      networking.nameservers = cfg.dns.upstreamServers;
      services.resolved = {
        enable = true;
        dnssec = cfg.dns.dnssec;
        dnsovertls = "true";
      };
    })

    (mkIf (cfg.dns.enable && cfg.dns.mode == "doh") {
      networking.nameservers = [
        "127.0.0.1"
        "::1"
      ];
      networking.networkmanager.dns = "none";
      networking.dhcpcd.extraConfig = "nohook resolv.conf";

      services.dnscrypt-proxy2 = {
        enable = true;
        settings = {
          listen_addresses = [
            "127.0.0.1:53"
            "[::1]:53"
          ];
          dnscrypt_servers = false;
          doh_servers = true;
          require_dnssec = if cfg.dns.dnssec == "true" then true else false;
          bootstrap_resolvers = [
            "9.9.9.9:53"
            "1.1.1.1:53"
          ];
        };
      };
    })

    # Time Synchronization Config
    (mkIf (cfg.time.enable && cfg.time.mode == "client") {
      networking.timeServers = cfg.time.servers;
      services.timesyncd.enable = true;
    })

    (mkIf (cfg.time.enable && cfg.time.mode == "server") {
      services.timesyncd.enable = false;
      services.chrony = {
        enable = true;
        servers = cfg.time.servers;
        extraConfig = ''
          ${concatMapStringsSep "\n" (subnet: "allow ${subnet}") cfg.time.allowedClients}
          local stratum 10
        '';
      };
    })

    # Nftables Firewall Config
    (mkIf cfg.firewall.enable {
      networking.firewall.enable = false;
      networking.nftables = {
        enable = true;
        ruleset = ''
          table inet filter {
            ${optionalString cfg.firewall.rateLimitSsh.enable ''
              set ssh_meter {
                type ipv4_addr
                flags dynamic, timeout
                timeout 1m
              }
            ''}

            chain input {
              type filter hook input priority filter; policy drop;

              ct state established,related accept
              ct state invalid drop
              iifname "lo" accept

              ip protocol icmp accept
              ip6 nexthdr icmpv6 accept

              ${optionalString (
                cfg.firewall.trustedInterfaces != [ ]
              ) "iifname ${toNftIfaceSet cfg.firewall.trustedInterfaces} accept"}
              ${optionalString (
                cfg.firewall.allowedTcpPorts != [ ]
              ) "tcp dport ${toNftSet cfg.firewall.allowedTcpPorts} accept"}
              ${optionalString (
                cfg.firewall.allowedUdpPorts != [ ]
              ) "udp dport ${toNftSet cfg.firewall.allowedUdpPorts} accept"}

              # NTP Ingress Rule Construction
              ${optionalString (cfg.time.enable && cfg.time.mode == "server") (
                if cfg.time.allowedClients != [ ] then
                  "ip saddr ${toNftSubnetSet cfg.time.allowedClients} udp dport 123 accept"
                else
                  "udp dport 123 accept"
              )}

              ${optionalString cfg.firewall.allowLocalDiscovery ''
                udp dport { 137, 138, 5353, 5355 } pkttype multicast accept
                udp dport { 137, 138, 5353, 5355 } accept
              ''}

              ${optionalString cfg.firewall.rateLimitSsh.enable ''
                tcp dport 22 ct state new update @ssh_meter { ip saddr limit rate over ${toString cfg.firewall.rateLimitSsh.maxConnections}/minute } drop
                tcp dport 22 ct state new accept
              ''}

              ${cfg.firewall.extraInputRules}
            }

            chain forward {
              type filter hook forward priority filter; policy drop;
              ct state established,related accept
              ct state invalid drop

              ${optionalString
                (
                  cfg.routing.enableForwarding
                  && cfg.firewall.nat.enable
                  && cfg.firewall.nat.externalInterface != null
                  && cfg.firewall.nat.internalInterfaces != [ ]
                )
                ''
                  iifname ${toNftIfaceSet cfg.firewall.nat.internalInterfaces} oifname "${cfg.firewall.nat.externalInterface}" accept
                ''
              }

              ${cfg.firewall.extraForwardRules}
            }

            chain output {
              type filter hook output priority filter; policy accept;
            }
          }

          ${optionalString (cfg.firewall.nat.enable && cfg.firewall.nat.externalInterface != null) ''
            table ip nat {
              chain postrouting {
                type filter hook postrouting priority srcnat; policy accept;
                oifname "${cfg.firewall.nat.externalInterface}" masquerade
              }
            }
          ''}
        '';
      };
    })
  ];
}
