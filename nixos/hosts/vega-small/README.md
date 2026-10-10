# vega-small

Desktop (WSL deployment, Windows 11)

Refer to [vega](../vega/README.md) for system's
hardware configuration.

The host directly selects the existing CachyOS bore LTO x86_64-v3 package and
scx_rustland in Auto mode. `scheduler.nix` retains the complete scheduler
configuration and argument lists. WSL still uses Windows' running kernel and
clock: ntpd-rs, timesyncd, and chrony are disabled. DNS remains WSL-managed;
Kepler's DoH service composition is not applied here.

The native nftables firewall has no global TCP/UDP openings. TCP/UDP 53 is
permitted only on the declarative `selfhosted0` container bridge if it exists;
loopback, ICMP/ping, and DHCPv6 use the native firewall rules. No DNS or NTP
server listener is enabled.

The system toplevel evaluation and dry-build are covered by the commands in
[`tests/README.md`](../../../tests/README.md). Live Windows/WSL resume and clock
synchronization behavior has not been tested by activating this checkout.
