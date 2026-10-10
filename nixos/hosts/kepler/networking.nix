{ pkgs, ... }:
let
  # Public bootstrap policy; the mutable file may later contain private paths.
  publicUpstreams = pkgs.writeText "dnsproxy-public-upstreams" "https://cloudflare-dns.com/dns-query\n";
  validateUpstreams = pkgs.writeShellScript "validate-doh-upstreams" ''
    # Read systemd's protected credential, never echo endpoint identifiers.
    if ! ${pkgs.gawk}/bin/awk '
      /^[[:space:]]*(#|$)/ { next }
      { count++; if ($0 !~ /^https:\/\/[^\/@?#[:space:]]+(\/[^?#[:space:]]*)?$/) invalid=1 }
      END { exit (invalid || !count) }
    ' "$1"; then
      echo "dnsproxy requires HTTPS upstreams without userinfo, query parameters, or fragments" >&2
      exit 1
    fi
  '';
in
{
  preferences.networking = {
    time = {
      enable = true;
      mode = "client";
    };
    firewall.enable = true;
  };
  networking.optimizations.enable = true;

  # The global ~. route takes ordinary queries; VPN routes such as ~corp.example
  # are more specific and remain supplied by NetworkManager to resolved.
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNS = [
        "127.0.0.1:5354"
        "[::1]:5354"
      ];
      Domains = [ "~." ];
      FallbackDNS = "";
      DNSOverTLS = false; # Plaintext loopback hop; dnsproxy encrypts externally.
      DNSSEC = false; # Explicit policy compatible with filtering/rewrites.
      LLMNR = false;
      MulticastDNS = false;
    };
  };

  services.dnsproxy = {
    enable = true;
    settings = {
      listen-addrs = [
        "127.0.0.1"
        "::1"
      ];
      listen-ports = [ 5354 ];
      # These IPs resolve only the endpoint hostname, independently of resolved.
      bootstrap = [
        "1.1.1.1:53"
        "1.0.0.1:53"
      ];
      fallback = [ ];
      dnssec = false; # DO-bit requests are not local DNSSEC validation.
      insecure = false;
      use-private-rdns = false;
      output = "/run/dnsproxy/dnsproxy.log";
    };
    flags = [ "--upstream=%d/upstreams" ];
  };

  # C only initializes missing files. Locally supplied private endpoints survive
  # switches and never enter a Nix expression or generated store configuration.
  systemd.tmpfiles.rules = [
    "d /etc/dnsproxy 0700 root root -"
    "C /etc/dnsproxy/upstreams 0600 root root - ${publicUpstreams}"
  ];
  systemd.services.dnsproxy.serviceConfig = {
    LoadCredential = "upstreams:/etc/dnsproxy/upstreams";
    ExecStartPre = "${validateUpstreams} %d/upstreams";
    RuntimeDirectory = "dnsproxy";
    RuntimeDirectoryMode = "0700";
    UMask = "0077";
    ProtectSystem = "strict";
    # Startup/error output may contain an upstream URL. Logs are confined to
    # the protected runtime directory, including when initialization fails.
    StandardOutput = "null";
    StandardError = "null";
  };
}
