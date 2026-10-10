{ inputs, pkgs }:
let
  rules = import ./networking.nix { inherit inputs pkgs; };
  image = pkgs.dockerTools.buildImage {
    name = "network-probe";
    tag = "latest";
    copyToRoot = pkgs.buildEnv {
      name = "probe-root";
      paths = [
        pkgs.busybox
        pkgs.bind.dnsutils
      ];
      ignoreCollisions = true;
      pathsToLink = [ "/bin" ];
    };
    config.Cmd = [ "/bin/sh" ];
  };
in
pkgs.testers.runNixOSTest {
  name = "native-networking";
  nodes.machine = { lib, pkgs, ... }: {
    imports = [
      ../nixos/modules/preferences/networking.nix
      ../nixos/modules/fast-networking.nix
      ../nixos/hosts/kepler/networking.nix
      ../nixos/modules/containers.nix
      inputs.quadlet-nix.nixosModules.quadlet
    ];
    virtualisation.memorySize = 1536;
    virtualisation.podman.enable = true;
    networking.networkmanager.enable = true;
    services.openssh.enable = true;
    preferences.networking = {
      firewall.rateLimitSsh = {
        enable = true;
        maxConnections = 2;
      };
      time = {
        mode = lib.mkForce "server";
        allowedClients = [
          "192.0.2.2/32"
          "fd00::2/128"
        ];
      };
    };
    # No external network or clock source is needed for the packet ACL tests.
    services.ntpd-rs.useNetworkingTimeServers = false;
    services.dnsproxy.settings.bootstrap = lib.mkForce [ "127.0.0.2:53" ];
    services.dnsproxy.settings.timeout = "1s";
    systemd.services.dnsproxy = {
      after = [ "dns-fixture.service" ];
      wants = [ "dns-fixture.service" ];
      environment.SSL_CERT_FILE = "/run/dns-fixture/cert.pem";
    };
    environment.systemPackages = [
      pkgs.bind
      pkgs.python3
      pkgs.openssl
      pkgs.iproute2
      pkgs.dnsmasq
    ];
    systemd.services.dns-fixture = {
      wantedBy = [ "multi-user.target" ];
      before = [ "dnsproxy.service" ];
      serviceConfig = {
        RuntimeDirectory = "dns-fixture";
        Type = "simple";
      };
      path = [ pkgs.openssl ];
      preStart = ''
        openssl req -x509 -newkey rsa:2048 -nodes -days 1 \
          -subj /CN=endpoint.test \
          -addext 'subjectAltName=DNS:endpoint.test,DNS:endpoint6.test' \
          -keyout /run/dns-fixture/key.pem -out /run/dns-fixture/cert.pem
      '';
      script = "exec ${pkgs.python3}/bin/python3 ${./dns-fixture.py}";
    };
  };
  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("dns-fixture.service")

    def upstream(url):
        machine.succeed("printf '%s\\n' '" + url + "' > /etc/dnsproxy/upstreams")
        machine.succeed("systemctl reset-failed dnsproxy; systemctl restart dnsproxy")
        machine.wait_for_unit("dnsproxy.service")
        machine.succeed("resolvectl flush-caches")

    def query(name, options=""):
        return machine.succeed("dig +time=2 +tries=1 @127.0.0.53 " + name + " " + options)

    with subtest("path-based HTTPS, separate IPv4/IPv6 loopback listeners, bootstrap"):
        upstream("https://endpoint.test:8443/private-test-path/dns-query")
        machine.wait_until_succeeds("dig +short @127.0.0.53 ordinary.test | grep 198.51.100.7")
        machine.succeed("dig +short @::1 -p 5354 ipv6.test AAAA | grep 2001:db8::7")
        machine.succeed("dig +tcp +short @127.0.0.1 -p 5354 tcp.test | grep 198.51.100.7")
        machine.succeed("grep '^/private-test-path/dns-query$' /run/dns-fixture/paths.log")
        machine.succeed("grep '^endpoint.test$' /run/dns-fixture/plain.log")
        machine.fail("grep '^ordinary.test$' /run/dns-fixture/plain.log")
        # A stub on :53 and the proxy on :5354 coexist; neither proxy socket is public.
        machine.succeed("ss -lnut | grep '127.0.0.1:5354'")
        machine.succeed("ss -lnut | grep '\\[::1\\]:5354'")
        machine.fail("ss -lnut | grep -E '(0.0.0.0|\\[::\\]):5354'")

    with subtest("protected credentials/logs and restart"):
        machine.succeed("test $(stat -c %a /etc/dnsproxy/upstreams) = 600")
        machine.succeed("test $(stat -c %a /run/dnsproxy) = 700")
        machine.succeed("test $(stat -c %a /run/dnsproxy/dnsproxy.log) = 600")
        machine.fail("journalctl -u dnsproxy --no-pager | grep private-test-path")
        machine.fail("grep -R private-test-path /etc/systemd/system/dnsproxy.service /etc/systemd/resolved.conf")
        machine.succeed("systemctl reset-failed dnsproxy; systemctl restart dnsproxy")
        machine.wait_until_succeeds("dig +short @127.0.0.53 restart.test | grep 198.51.100.7")

    with subtest("cold boot preserves the runtime upstream file"):
        machine.shutdown()
        machine.start()
        machine.wait_for_unit("dnsproxy.service")
        machine.wait_until_succeeds("dig +short @127.0.0.53 coldboot.test | grep 198.51.100.7")
        machine.succeed("grep private-test-path /etc/dnsproxy/upstreams")

    with subtest("encrypted IPv6 upstream"):
        upstream("https://endpoint6.test:8443/ipv6/dns-query")
        machine.wait_until_succeeds("dig +short @127.0.0.53 external6.test | grep 198.51.100.7")
        machine.succeed("grep '^/ipv6/dns-query$' /run/dns-fixture/paths.log")

    with subtest("DHCP/reconnect and competing connection DNS defaults"):
        machine.succeed("ip netns add dhcp; ip link add dhcp-test type veth peer name dhcp-server; ip link set dhcp-server netns dhcp")
        machine.succeed("ip netns exec dhcp ip link set lo up; ip netns exec dhcp ip addr add 192.168.77.1/24 dev dhcp-server; ip netns exec dhcp ip link set dhcp-server up")
        machine.succeed("ip netns exec dhcp dnsmasq --interface=dhcp-server --bind-interfaces --port=0 --dhcp-range=192.168.77.100,192.168.77.110,60s --dhcp-option=6,127.0.0.2 --pid-file=/run/dhcp-fixture.pid")
        machine.succeed("nmcli con add type ethernet ifname dhcp-test con-name dhcp-test ipv4.method auto ipv6.method disabled")
        machine.succeed("nmcli con up dhcp-test")
        machine.succeed("ip -4 addr show dhcp-test | grep -E '192[.]168[.]77[.](10[0-9]|110)/24'")
        assert "198.51.100.7" in query("dhcp-default.test")
        machine.succeed("nmcli con down dhcp-test; nmcli con up dhcp-test")
        machine.succeed("ip -4 addr show dhcp-test | grep -E '192[.]168[.]77[.](10[0-9]|110)/24'")
        machine.succeed("nmcli con delete dhcp-test; ip link delete dhcp-test; ip netns delete dhcp")

    with subtest("VPN-style specific domains keep connection-managed DNS"):
        machine.succeed("nmcli con add type dummy ifname vpn-test con-name vpn-test ipv4.method manual ipv4.addresses 10.99.0.1/24 ipv4.dns 127.0.0.2 ipv4.dns-search '~corp.example' ipv4.never-default yes ipv6.method disabled")
        machine.succeed("nmcli con up vpn-test")
        machine.wait_until_succeeds("resolvectl status vpn-test | grep '~corp.example'")
        assert "198.51.100.44" in query("host.corp.example")
        assert "198.51.100.7" in query("outside.test")
        machine.succeed("grep '^host.corp.example$' /run/dns-fixture/plain.log")
        machine.fail("grep '^outside.test$' /run/dns-fixture/plain.log")
        machine.succeed("nmcli con down vpn-test && nmcli con up vpn-test")
        machine.wait_until_succeeds("dig +short @127.0.0.53 reconnect.corp.example | grep 198.51.100.44")
        machine.succeed("nmcli con delete vpn-test")

    with subtest("TLS verification and no ordinary-query plaintext fallback"):
        upstream("https://wrong-host.test:8443/dns-query")
        assert "SERVFAIL" in query("tls-rejected.test")
        machine.fail("grep '^tls-rejected.test$' /run/dns-fixture/plain.log")
        machine.fail("journalctl -u dnsproxy --no-pager | grep wrong-host.test")
        upstream("https://endpoint.test:9999/unavailable")
        assert "SERVFAIL" in query("upstream-failure.test")
        machine.fail("grep '^upstream-failure.test$' /run/dns-fixture/plain.log")
        upstream("https://endpoint.test:8443/dns-query")
        machine.wait_until_succeeds("dig +short @127.0.0.53 recovered.test | grep 198.51.100.7")

    with subtest("reject query-bearing URLs and plaintext upstreams without leaking them"):
        for url in ["https://endpoint.test:8443/dns-query?private=bad", "192.0.2.53:53"]:
            machine.succeed("printf '%s\\n' '" + url + "' > /etc/dnsproxy/upstreams")
            machine.succeed("systemctl reset-failed dnsproxy")
            machine.fail("systemctl restart dnsproxy")
        machine.fail("journalctl -u dnsproxy --no-pager | grep 'private=bad'")
        upstream("https://endpoint.test:8443/dns-query")

    with subtest("NTP IPv4/IPv6 allowlists, ICMP/NDP, and SSH limiter before native accept"):
        machine.wait_for_unit("ntpd-rs.service")
        machine.succeed("ip netns add peer; ip link add peer-host type veth peer name peer-ns; ip link set peer-ns netns peer")
        machine.succeed("ip addr add 192.0.2.1/24 dev peer-host; ip -6 addr add fd00::1/64 dev peer-host; ip link set peer-host up")
        machine.succeed("ip netns exec peer ip link set lo up; ip netns exec peer ip link set peer-ns up")
        for address in ["192.0.2.2/24", "192.0.2.3/24"]:
            machine.succeed("ip netns exec peer ip addr add " + address + " dev peer-ns")
        for address in ["fd00::2/64", "fd00::3/64"]:
            machine.succeed("ip netns exec peer ip -6 addr add " + address + " dev peer-ns")
        machine.succeed("ip netns exec peer ping -c 1 192.0.2.1")
        machine.wait_until_succeeds("ip netns exec peer ping -c 1 fd00::1")
        probe = "ip netns exec peer python3 ${./network-probe.py} "
        machine.succeed(probe + "ntp 192.0.2.1 192.0.2.2")
        machine.fail(probe + "ntp 192.0.2.1 192.0.2.3")
        machine.succeed(probe + "ntp fd00::1 fd00::2")
        machine.fail(probe + "ntp fd00::1 fd00::3")
        machine.succeed(probe + "ssh 192.0.2.1 192.0.2.2")
        machine.succeed(probe + "ssh fd00::1 fd00::2")

    with subtest("rootful selfhosted container DNS over UDP/TCP and outbound NAT"):
        machine.succeed("systemctl start selfhosted-network.service")
        machine.succeed("podman load -i ${image}")
        machine.succeed("podman run --detach --name dns-probe --network selfhosted network-probe sleep 600")
        machine.succeed("podman exec dns-probe nslookup container.test | grep 198.51.100.7")
        gateway = machine.succeed("podman network inspect selfhosted --format '{{(index .Subnets 0).Gateway}}'").strip()
        machine.succeed("podman exec dns-probe dig +tcp +short @" + gateway + " container-tcp.test | grep 198.51.100.7")
        machine.succeed("systemd-run --unit=peer-http ${pkgs.iproute2}/bin/ip netns exec peer ${pkgs.python3}/bin/python3 -m http.server 8000 --bind 192.0.2.2")
        machine.wait_for_unit("peer-http.service")
        machine.wait_until_succeeds("ip netns exec peer ss -lnt | grep ':8000'", timeout=10)
        machine.wait_until_succeeds("podman exec dns-probe wget -qO- http://192.0.2.2:8000", timeout=10)
        machine.succeed("journalctl -u peer-http --no-pager | grep 192.0.2.1")
        machine.succeed("systemctl restart nftables")
        machine.succeed("podman exec dns-probe nslookup container-reload.test | grep 198.51.100.7")
        machine.succeed("podman exec dns-probe wget -qO- http://192.0.2.2:8000")

    with subtest("native router forwarding/NAT and unsolicited ingress rejection"):
        machine.succeed("sed '/^[[:space:]]*include /d' ${rules}/router.nft > /run/router.nft")
        for ns in ["router", "lan", "wan"]:
            machine.succeed("ip netns add " + ns + "; ip netns exec " + ns + " ip link set lo up")
        for iface, ns in [("lan0", "lan"), ("wan0", "wan")]:
            machine.succeed("ip link add " + iface + " type veth peer name " + ns + "-peer")
            machine.succeed("ip link set " + iface + " netns router; ip link set " + ns + "-peer netns " + ns)
            machine.succeed("ip netns exec router ip link set " + iface + " up; ip netns exec " + ns + " ip link set " + ns + "-peer up")
        machine.succeed("ip netns exec router ip addr add 10.50.0.1/24 dev lan0; ip netns exec router ip addr add 192.0.2.1/24 dev wan0")
        machine.succeed("ip netns exec lan ip addr add 10.50.0.2/24 dev lan-peer; ip netns exec lan ip route add default via 10.50.0.1")
        machine.succeed("ip netns exec wan ip addr add 192.0.2.2/24 dev wan-peer; ip netns exec wan ip route add default via 192.0.2.1")
        machine.succeed("ip netns exec router sysctl -w net.ipv4.ip_forward=1; ip netns exec router nft -f /run/router.nft")
        machine.succeed("ip netns exec lan ping -c 1 -W 2 192.0.2.2")
        machine.fail("ip netns exec wan ping -c 1 -W 1 10.50.0.2")
        machine.succeed("ip netns exec router ip -6 addr add fd50:1::1/64 dev lan0; ip netns exec router ip -6 addr add fd50:2::1/64 dev wan0")
        machine.succeed("ip netns exec lan ip -6 addr add fd50:1::2/64 dev lan-peer; ip netns exec lan ip -6 route add default via fd50:1::1")
        machine.succeed("ip netns exec wan ip -6 addr add fd50:2::2/64 dev wan-peer; ip netns exec wan ip -6 route add default via fd50:2::1")
        machine.succeed("ip netns exec router sysctl -w net.ipv6.conf.all.forwarding=1")
        machine.wait_until_succeeds("ip netns exec lan ping -c 1 -W 2 fd50:2::2")

  '';
}
