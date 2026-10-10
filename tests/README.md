# Configuration validation

Run from the repository root:

```console
./tasks.nu fmt
./tasks.nu check
./tasks.nu networking-check
./tasks.nu configuration-check
./tasks.nu networking-test
./tasks.nu eval nixosConfigurations.kepler.config.system.build.toplevel.drvPath
./tasks.nu eval nixosConfigurations.vega-small.config.system.build.toplevel.drvPath
./tasks.nu dry-build --host kepler
./tasks.nu dry-build --host vega-small
```

`configuration-check` is also part of normal flake checks. It checks both hosts'
generated Niri includes, Ghostty, Fuzzel, Zellij, Hyprlock, Ashell, MPV, tuigreet,
Git, Tealdeer, Nushell, RTKit arguments, scheduler mode arguments, and tmpfiles rules with the pinned
programs. Tuigreet's effective TOML dump must retain every configured field.
BlueZ keys are checked against the supported group/option tables in its pinned
source, including nonnegative reconnect intervals. GTK2 settings are checked against
the actual library's properties. WirePlumber's Bluetooth property scopes and codecs
are checked against pinned PipeWire documentation/source, and policy settings
against WirePlumber's installed schema. Negative cases confirm that unknown flags,
ignored Ashell fields, obsolete Hyprlock options, and unsupported BlueZ settings
are detected. Logs are kept in the check derivation's output by hostname.

Bottom, Jujutsu and Lazygit settings are validated against the JSON schemas
shipped in their pinned source, rejecting undocumented fields in objects with
known properties while retaining explicitly extensible sections. Jujutsu's push
bookmark template is parsed in a temporary repository. The configured prefix is
preserved, and automatic bookmark tracking is configured for the `origin` remote
using the current per-remote setting. No existing repository is modified.

These checks isolate HOME, XDG paths and the Wayland socket. Ashell and Hyprlock
parse their configuration before the deliberate missing-compositor failure;
the test requires reaching that boundary without parser errors. No screen is
locked and no scheduler is attached. MPV parses its full configuration while
playing one generated frame without video/audio output. Missing fonts in the
build sandbox are not evidence that the configured host lacks those fonts.
Tmpfiles runs with `--dry-run` against a temporary root with fixture account
records, so it does not create or remove live system paths.

The separate AppArmor check compiles all 13 named profile variants with the
pinned parser, include files and policy ABI. It skips kernel loading and caches;
it verifies syntax and include resolution, not effective application access.
The Zswap check covers current kernels, a 6.12 kernel, disabled operation, and
rejection of an unavailable allocator on Linux 6.15 and newer.

The 2026-10-10 pass-through audit corrected unsupported BlueZ keys, the RTKit
limit flag/unit, WirePlumber hardware-volume property scope, Hyprlock widget names,
CLI grace period and Kepler PAM entry, Ashell's enum/table
fields and bar appearance, the GTK2 dark-theme property, duplicate greeter cache
rules, the built-in intel_pstate module entry, the renamed Xe display parameter,
removed mitigation aliases, Zswap's removed allocator parameter/sysfs entry,
Bottom's temperature section, Jujutsu's tracking/push-template settings,
Lazygit's diff-renderer/icon settings, and
AppArmor includes outside profile blocks or referencing a nonexistent abstraction.

Additional inspection used the patched CachyOS 7.2.8 source for kernel parameters
and the pinned Hyprpaper source for its registered wallpaper settings. The
generated udev rules built through NixOS's validation builder. Containerd's native
configuration dump preserved the smolvm runtime and CNI path; its supported
version-2 input is migrated by containerd to version 4. WirePlumber's configured
Bluetooth policy, codec and hardware-volume keys were checked against the pinned
configuration/schema. No private runtime endpoint or environment file was read.
Rendering, actual hardware/kernel behavior, service activation, and supplied
runtime secrets still require checks on the deployed machines.

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
