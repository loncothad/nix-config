# kepler

Laptop

## Hardware configuration

#### Lenovo XiaoXin Pro 16 GT 2026 IPH11

* **Display:** 2880x1800, 16", 120 Hz, OLED
* **CPU:** Intel Core Ultra X9 388H (x86_64-v3; no AVX512)
* **GPU:** Intel Arc B390 (Integrated)
* **RAM:** 32GB
* **SSDs:** M.2 1 TB, M.2 2 TB
* **Wireless module:** Intel BE200 (Wi-Fi 7 / Bluetooth 5.4)

## Notes

* 150% scaling is preferred


## Kernel and scheduler

The host directly selects CachyOS bore LTO x86_64-v3 and scx_rusty in Auto mode.
`scheduler.nix` preserves every previously configured scheduler argument list,
including the selectable modes, without retuning them.

## Networking

`networking.nix` uses native systemd-resolved and dnsproxy 0.86.0:

```text
applications -> resolved stub (:53) -> loopback dnsproxy (:5354) -> HTTPS resolver
```

The hop between resolved and dnsproxy is plaintext on loopback. External ordinary
queries use HTTPS with certificate verification. There is no ordinary-query
plaintext fallback. Bootstrap queries for the HTTPS endpoint hostname use
1.1.1.1/1.0.0.1 over port 53 independently of the local resolver. They disclose
the endpoint hostname, including during cold boot, but never its URL path.
A bootstrap failure or unavailable HTTPS upstream causes resolution failure,
rather than substitution of a plaintext resolver.

NetworkManager continues to supply connection DNS and private-domain routes to
resolved. Global `~.` directs ordinary queries to the proxy; more specific VPN
routes such as `~corp.example` win. DHCP DNS without a matching routing domain
is not used for ordinary queries. A connection explicitly advertising its own
`~.` ties with the global route and can cause parallel queries to both. Review
that route on the actual VPN with `./tasks.nu networking-status` and decide
whether that VPN should own all DNS or only its private domains. Do not globally
disable NetworkManager DNS to work around it. Private-domain queries intentionally
follow the VPN's DNS policy and may use plaintext within that tunnel.

Local DNSSEC validation is explicitly disabled, as is dnsproxy's DNSSEC DO-bit
request setting. DoH authenticates the resolver transport; it does not perform
local DNSSEC validation. This policy accommodates filtered or rewritten answers.
A remote resolver can independently validate DNSSEC. Enabling local validation
requires checking the selected resolver's rewrites and the actual VPN.

### Upstreams and private endpoints

The first boot copies the public Cloudflare HTTPS endpoint to the root-owned
`/etc/dnsproxy/upstreams` file (0600; parent directory 0700). This retains one
previously configured unfiltered resolver as the migration baseline. Subsequent
switches preserve that file; final provider selection remains a separate decision.
Use `./tasks.nu dns-upstreams` on Kepler to edit it and restart the service. It
contains one HTTPS URL per line. Custom paths are supported. Query parameters,
fragments, embedded credentials, plaintext entries, and empty files are rejected.
The pinned proxy replaces existing URL query parameters, so a query-bearing
provider format is not supported by this configuration.

Systemd loads the file as a protected runtime credential. Put private endpoint
identifiers only in this local file, never in Nix expressions, CLI flags, or
committed files. The Nix store contains the public initialization endpoint and
runtime file paths only. Endpoint-bearing logs are confined to
`/run/dnsproxy/dnsproxy.log`, with a 0700 directory and 0600 log. Stdout/stderr are
suppressed because startup errors can include upstream URLs. Logs disappear on
restart; avoid copying them into tickets without inspecting/redacting them.

Candidate comparison:

| Candidate | Policy | Bootstrap for that candidate | HTTPS endpoint |
| --- | --- | --- | --- |
| Quad9 | Threat blocking; privacy policy says client IPs are not retained | 9.9.9.9 / 149.112.112.112 | `https://dns.quad9.net/dns-query` |
| Cloudflare standard | Unfiltered recursive service; separate public resolver privacy policy | 1.1.1.1 / 1.0.0.1 | `https://cloudflare-dns.com/dns-query` |

See [Quad9 services](https://docs.quad9.net/services/),
[Quad9 privacy](https://www.quad9.net/privacy/policy/),
[Cloudflare resolver variants](https://developers.cloudflare.com/1.1.1.1/infrastructure/network-operators/),
and [Cloudflare privacy](https://developers.cloudflare.com/1.1.1.1/privacy/public-dns-resolver/).
Select one filtering policy; do not add the other provider as an accidental
fallback. If changing provider, independently review native dnsproxy `bootstrap`
settings. Bootstrap resolvers do not determine the ordinary-query filtering policy.

`./tasks.nu networking-compare` sends only public A/AAAA queries to each candidate
with TLS verification, without changing DNS. Run it on Kepler on Wi-Fi and again
on the intended VPN. On the development WSL network on 2026-10-10, Cloudflare
completed 6/6 requests (median 191.8 ms including HTTPS connection overhead);
all 6 Quad9 requests failed with HTTP errors on that network. This is not a Kepler/VPN benchmark or
a reason to permanently select a provider. No private-domain queries were sent.

### Time and firewall

ntpd-rs runs as a client with nonsmearing time sources. Server mode requires an
explicit non-universal IPv4/IPv6 client allowlist; the daemon and firewall both
enforce it. A single dual-stack socket avoids the pinned daemon's conflicting
wildcard binds, with derived IPv4-mapped CIDRs in its daemon ACL. IPv4-only
systems use an IPv4 listener. Disabled mode disables ntpd-rs and timesyncd.

The native nftables firewall honors service declarations and DHCP/ICMPv6/NDP
handling. Effective openings are:

| Scope | Inbound opening |
| --- | --- |
| All external interfaces | UDP 68 for NetworkManager DHCPv4; native ICMP/ping and DHCPv6 rules |
| `selfhosted0` only | TCP/UDP 53 for Aardvark container DNS |
| Loopback only | resolved :53 and dnsproxy :5354 |

There are no global TCP openings, SSH/NTP server openings, audio UDP 6001/6002,
NetBIOS 137/138, mDNS 5353, or LLMNR 5355 openings. Local discovery is off. If
needed later, enable only multicast mDNS on explicit discovery interfaces.

The optional SSH limiter drops excessive new SYNs in an earlier dual-stack input
chain, before native trusted-interface/port accepts. It uses the configured SSH
ports and does not itself open them. Native router NAT uses `type nat` chains
and explicit internal/external interfaces. Netavark owns container forwarding
and NAT; default host forwarding filtering stays off so its traffic is not
dropped by a second firewall. NixOS reloads retain container-owned tables.
Network tuning retains BBR/CAKE and PMTU black-hole probing; memory scaling,
conntrack limits/timeouts, and other transport settings use kernel defaults.

## Validation and remaining live checks

See [`tests/README.md`](../../../tests/README.md) for commands and coverage.
The offline VM checks exercise native units, cold boot, DHCP/reconnect,
IPv4/IPv6, VPN-style split DNS, TLS failures, endpoint protection, time ACLs,
SSH limiting, and routing/container behavior. They do not validate Kepler's real
Wi-Fi, actual VPN or provider filtering/false positives, captive portals,
NTP upstream availability/clock accuracy, or suspend/resume on its hardware.
Those checks require activating the change on the target host and remain unrun.
