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
    optional
    filter
    hasInfix
    ;

  toNftSet = items: "{ ${concatMapStringsSep ", " toString items} }";
  toNftIfaceSet = ifaces: "{ ${concatMapStringsSep ", " (i: ''"${i}"'') ifaces} }";
  ntpServer = cfg.time.enable && cfg.time.mode == "server";
  clientSubnets = map (
    client:
    if hasInfix "/" client then client else "${client}/${if hasInfix ":" client then "128" else "32"}"
  ) cfg.time.allowedClients;
  ipv4Clients = filter (client: !(hasInfix ":" client)) clientSubnets;
  ipv6Clients = filter (client: hasInfix ":" client) clientSubnets;

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
          - 'client': Run ntpd-rs without listening for downstream peers.
          - 'server': Run ntpd-rs with an explicit downstream client allowlist.
        '';
      };
      servers = mkOption {
        type = types.listOf types.str;
        default = [
          "time.cloudflare.com"
          "0.nixos.pool.ntp.org"
          "1.nixos.pool.ntp.org"
          "2.nixos.pool.ntp.org"
        ];
        description = "Upstream NTP servers. Defaults use nonsmearing sources; do not mix these with leap-smearing services.";
      };
      allowedClients = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Explicit IPv4/IPv6 subnets or addresses permitted to poll this machine in server mode. Empty or universal allowlists are rejected.";
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
      discoveryInterfaces = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Interfaces on which to allow multicast mDNS when local discovery is enabled. NetBIOS and LLMNR are not opened.";
      };
      rateLimitSsh = {
        enable = mkOption {
          type = types.bool;
          default = false;
        };
        maxConnections = mkOption {
          type = types.ints.positive;
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

    {
      # A disabled preference must also disable NixOS's default time client.
      services.timesyncd.enable = false;
      services.ntpd-rs.enable = cfg.time.enable;
      assertions = [
        {
          assertion =
            ntpServer
            -> (
              clientSubnets != [ ]
              && !(builtins.elem "0.0.0.0/0" clientSubnets)
              && !(builtins.elem "::/0" clientSubnets)
            );
          message = "NTP server mode requires an explicit, non-public client allowlist.";
        }
        {
          assertion = cfg.firewall.allowLocalDiscovery -> cfg.firewall.discoveryInterfaces != [ ];
          message = "Local discovery requires explicit discoveryInterfaces.";
        }
        {
          assertion =
            cfg.firewall.nat.enable
            -> (
              cfg.routing.enableForwarding
              && cfg.firewall.nat.externalInterface != null
              && cfg.firewall.nat.internalInterfaces != [ ]
            );
          message = "NAT requires forwarding, an external interface, and explicit internal interfaces.";
        }
      ];
    }

    (mkIf cfg.time.enable {
      networking.timeServers = cfg.time.servers;
      services.ntpd-rs.settings.server =
        optional ntpServer {
          listen = "0.0.0.0:123";
          allowlist = {
            filter = clientSubnets;
            action = "ignore";
          };
        }
        ++ optional ntpServer {
          listen = "[::]:123";
          allowlist = {
            filter = clientSubnets;
            action = "ignore";
          };
        };
    })

    (mkIf cfg.firewall.enable {
      networking.nftables.enable = true;
      networking.firewall = {
        enable = true;
        # Loose reverse-path checks allow asymmetric/VPN routes. Native rules
        # handle DHCP and ICMPv6, including neighbor discovery.
        checkReversePath = "loose";
        allowedTCPPorts = cfg.firewall.allowedTcpPorts;
        allowedUDPPorts =
          cfg.firewall.allowedUdpPorts ++ optional config.networking.networkmanager.enable 68;
        trustedInterfaces = cfg.firewall.trustedInterfaces;
        # Netavark owns rootful container forwarding/NAT. Filtering forward
        # here would drop container traffic before its own rules can accept it.
        filterForward = cfg.firewall.nat.enable;
        extraInputRules = ''
          ${optionalString (
            ntpServer && ipv4Clients != [ ]
          ) "ip saddr ${toNftSet ipv4Clients} udp dport 123 accept"}
          ${optionalString (
            ntpServer && ipv6Clients != [ ]
          ) "ip6 saddr ${toNftSet ipv6Clients} udp dport 123 accept"}
          ${optionalString cfg.firewall.allowLocalDiscovery ''
            iifname ${toNftIfaceSet cfg.firewall.discoveryInterfaces} ip daddr 224.0.0.251 udp dport 5353 accept
            iifname ${toNftIfaceSet cfg.firewall.discoveryInterfaces} ip6 daddr ff02::fb udp dport 5353 accept
          ''}
          ${cfg.firewall.extraInputRules}
        '';
        extraForwardRules = cfg.firewall.extraForwardRules;
      };

      networking.nat = {
        inherit (cfg.firewall.nat) enable externalInterface internalInterfaces;
      };

      # A separate earlier base chain can drop traffic before trusted-interface
      # and allowed-port accepts. It never accepts or opens an SSH port itself.
      networking.nftables.tables.ssh-rate-limit = mkIf cfg.firewall.rateLimitSsh.enable {
        family = "inet";
        content = ''
          set ssh4 {
            type ipv4_addr
            flags dynamic, timeout
            timeout 1m
          }
          set ssh6 {
            type ipv6_addr
            flags dynamic, timeout
            timeout 1m
          }
          chain input {
            type filter hook input priority filter - 10; policy accept;
            iifname != "lo" tcp dport ${toNftSet config.services.openssh.ports} ct state new tcp flags & (fin | syn | rst | ack) == syn update @ssh4 { ip saddr limit rate over ${toString cfg.firewall.rateLimitSsh.maxConnections}/minute } drop
            iifname != "lo" tcp dport ${toNftSet config.services.openssh.ports} ct state new tcp flags & (fin | syn | rst | ack) == syn update @ssh6 { ip6 saddr limit rate over ${toString cfg.firewall.rateLimitSsh.maxConnections}/minute } drop
          }
        '';
      };
    })
  ];
}
