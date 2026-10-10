{ inputs, pkgs }:
let
  inherit (pkgs) lib;
  system = pkgs.stdenv.hostPlatform.system;
  evaluate =
    extra:
    (inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ../nixos/modules/preferences/networking.nix
        ../nixos/modules/fast-networking.nix
        {
          boot.loader.grub.enable = false;
          fileSystems."/" = {
            device = "/dev/test";
            fsType = "ext4";
          };
          system.stateVersion = "26.05";
        }
        extra
      ];
    }).config;
  client = evaluate { };
  server = evaluate {
    preferences.networking.time = {
      mode = "server";
      allowedClients = [
        "192.0.2.0/24"
        "fd00::/64"
      ];
    };
  };
  server4 = evaluate {
    networking.enableIPv6 = false;
    preferences.networking.time = {
      mode = "server";
      allowedClients = [ "192.0.2.0/24" ];
    };
  };
  disabled = evaluate { preferences.networking.time.enable = false; };
  rejected = evaluate { preferences.networking.time.mode = "server"; };
  publicRejected = evaluate {
    preferences.networking.time = {
      mode = "server";
      allowedClients = [ "::/0" ];
    };
  };
  sshClosed = evaluate { preferences.networking.firewall.rateLimitSsh.enable = true; };
  router = evaluate {
    services.openssh = {
      enable = true;
      ports = [
        22
        2222
      ];
    };
    preferences.networking = {
      routing.enableForwarding = true;
      firewall = {
        rateLimitSsh.enable = true;
        allowLocalDiscovery = true;
        discoveryInterfaces = [ "lan0" ];
        nat = {
          enable = true;
          externalInterface = "wan0";
          internalInterfaces = [ "lan0" ];
        };
      };
    };
  };
  dns = evaluate {
    imports = [ ../nixos/hosts/kepler/networking.nix ];
    networking.networkmanager.enable = true;
  };
  ntpFile =
    config:
    let
      command = lib.last config.systemd.services.ntpd-rs.serviceConfig.ExecStart;
    in
    lib.addContextFrom command (builtins.head (builtins.match ".*--config=(.*)" command));
  nftFile = config: lib.last config.systemd.services.nftables.serviceConfig.ExecStart;
  serverRules = server.networking.nftables.tables.nixos-fw.content;
  sshRules = router.networking.nftables.tables.ssh-rate-limit.content;
  rejectedMessage = "NTP server mode requires an explicit, non-public client allowlist.";
  rejectsAcl =
    config: lib.any (item: item.message == rejectedMessage && !item.assertion) config.assertions;
in
assert client.services.ntpd-rs.enable && !client.services.timesyncd.enable;
assert client.services.ntpd-rs.settings.server == [ ];
assert (builtins.head server.services.ntpd-rs.settings.server).listen == "[::]:123";
assert (builtins.head server4.services.ntpd-rs.settings.server).listen == "0.0.0.0:123";
assert
  (builtins.head server4.services.ntpd-rs.settings.server).allowlist.filter == [ "192.0.2.0/24" ];
assert !disabled.services.ntpd-rs.enable && !disabled.services.timesyncd.enable;
assert rejectsAcl rejected && rejectsAcl publicRejected;
assert !(builtins.tryEval rejected.system.build.toplevel.drvPath).success;
assert !(builtins.tryEval publicRejected.system.build.toplevel.drvPath).success;
assert lib.all (
  item:
  item.allowlist.filter == [
    "192.0.2.0/24"
    "fd00::/64"
    "::ffff:192.0.2.0/120"
  ]
  && item.allowlist.action == "ignore"
) server.services.ntpd-rs.settings.server;
assert lib.hasInfix "ip saddr { 192.0.2.0/24 } udp dport 123 accept" serverRules;
assert lib.hasInfix "ip6 saddr { fd00::/64 } udp dport 123 accept" serverRules;
assert !(builtins.elem 123 server.networking.firewall.allowedUDPPorts);
assert sshClosed.networking.firewall.allowedTCPPorts == [ ];
assert lib.hasInfix "priority filter - 10" sshRules;
assert lib.hasInfix "type ipv4_addr" sshRules && lib.hasInfix "type ipv6_addr" sshRules;
assert
  lib.hasInfix "tcp dport { 22, 2222 }" sshRules && !(lib.hasInfix "ct state new accept" sshRules);
assert router.boot.kernel.sysctl."net.ipv6.conf.all.accept_ra" == 2;
assert lib.hasInfix "type nat hook postrouting" router.networking.nftables.tables.nixos-nat.content;
assert dns.networking.networkmanager.dns == "systemd-resolved";
assert dns.services.resolved.settings.Resolve.FallbackDNS == "";
assert dns.services.resolved.settings.Resolve.DNSSEC == false;
assert dns.services.dnsproxy.settings.fallback == [ ] && !dns.services.dnsproxy.settings.insecure;
assert
  dns.services.dnsproxy.settings.listen-addrs == [
    "127.0.0.1"
    "::1"
  ];
assert dns.services.dnsproxy.flags == [ "--upstream=%d/upstreams" ];
assert
  dns.systemd.services.dnsproxy.serviceConfig.LoadCredential == "upstreams:/etc/dnsproxy/upstreams";
pkgs.runCommand "networking-checks" { } ''
  mkdir -p $out
  # These files already pass the pinned upstream ntp-ctl validation builder
  # and native NixOS nftables syntax checker, including the limiter/NAT case.
  cp ${ntpFile client} $out/ntp-client.toml
  cp ${ntpFile server} $out/ntp-server.toml
  cp ${ntpFile server4} $out/ntp-server-ipv4.toml
  cp ${nftFile dns} $out/kepler.nft
  cp ${nftFile router} $out/router.nft
  cp ${nftFile server} $out/ntp-server.nft
''
