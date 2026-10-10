# Networking validation

Run from the repository root:

```console
./tasks.nu fmt
./tasks.nu check
./tasks.nu networking-check
./tasks.nu networking-test
./tasks.nu eval nixosConfigurations.kepler.config.system.build.toplevel.drvPath
./tasks.nu eval nixosConfigurations.vega-small.config.system.build.toplevel.drvPath
./tasks.nu dry-build --host kepler
./tasks.nu dry-build --host vega-small
```

`networking-check` is part of normal flake checks. It evaluates native DNS policy,
time client/server/disabled modes, dual-stack and IPv4-only allowlists, empty and
universal ACL rejection, scoped openings, limiter ordering without opening SSH,
and native router NAT. It builds ntpd-rs configuration through the pinned upstream
validation and native nftables rule derivations through their syntax checker.

`networking-test` is a separate offline NixOS VM test using the pinned modules and
binaries. It tests actual systemd credentials, protected logs, custom HTTPS paths,
bootstrap separation, cold boot/restart, loopback/HTTPS IPv6, UDP/TCP DNS, DHCP
and reconnection, NetworkManager split-domain routes, TLS hostname verification,
upstream failure/recovery, absence of ordinary-query plaintext fallback, malformed
upstream rejection, NTP ACLs and SSH limiting for both address families, ICMP/NDP,
rootful container DNS/NAT and firewall reload, and native router forwarding/NAT.
The fixture uses only test certificates and reserved addresses. No real private
endpoint belongs in these files. Local DNSSEC validation is disabled by the
explicit host policy; the fixture is not a DNSSEC cryptographic validation test.

The initial networking migration compared both hosts' complete kernel derivation
and scheduler settings with their pre-change values and matched them exactly
at nixpkgs `e94cb152ed51bd6e24eb4a41f1460252beb52cd2`. The 2026-10-10 input refresh
uses nixpkgs `e7439b6b14ad3cc35d05608ebca9bce01a25f5f8`; package/kernel versions
follow those updated inputs while scheduler choices and argument lists remain
unchanged. Rerun these checks after each input refresh.

On the development machine, pure full-host evaluation/check initially refused the
already configured unfree ChatGPT adapter package. Validation was also run with
that existing package permitted:

```console
NIXPKGS_ALLOW_UNFREE=1 ./tasks.nu check --impure
NIXPKGS_ALLOW_UNFREE=1 ./tasks.nu eval nixosConfigurations.kepler.config.system.build.toplevel.drvPath --impure
NIXPKGS_ALLOW_UNFREE=1 ./tasks.nu eval nixosConfigurations.vega-small.config.system.build.toplevel.drvPath --impure
NIXPKGS_ALLOW_UNFREE=1 ./tasks.nu dry-build --host kepler --impure
NIXPKGS_ALLOW_UNFREE=1 ./tasks.nu dry-build --host vega-small --impure
```

The standalone networking checks and VM do not require permitting unfree packages.
Dry-builds inspect build plans; complete host closures were not built or activated.
Actual Kepler hardware/network/VPN and Windows/WSL runtime checks remain required;
see the corresponding host READMEs. `./tasks.nu networking-compare` provides a
repeatable public-resolver comparison on the target network without changing DNS.
