# Architecture

Personal NixOS + Home Manager flake. Shared modules carry behavior; per-host
and per-user files only carry differences. Outside consumers can take
`nixosModules`, `homeModules`, `overlays`, and `packages` without this flake's
hosts or the `loncothad` user.

## Where things live

```
flake.nix                 inputs + flake-parts entry
flake-parts/              how this flake is composed (systems, exports, hosts)
flakes/                   nested flake-parts flakes for complex HM modules
nixos/modules/            reusable NixOS modules (no users enabled)
nixos/hosts/<name>/       host-only config; not a system until listed in
                          nixos/default.nix
home-manager/modules/     shared HM barrel and small local modules
home-manager/users/<name> user tree (packages + settings/)
disko/                    disk layouts, imported from NixOS
pkgs/                     overlay and local packages
misc/                     nushell scripts, ssh keys, assets
justfile                  repo recipes
```

`flake-parts/` wires outputs: NixOS systems from `nixos/default.nix`, the
shared NixOS module set, Home Manager modules (local plus nested flakes),
the overlay from `pkgs/`, packages, treefmt (`nix fmt` / `just fmt`), and
Disko configurations. `flake-parts/home-modules.nix` makes
`flake.homeModules` a mergeable attrs-of-modules option so nested flakes can
contribute keys.

`nixos/default.nix` builds each listed host with `mkNixOsSystem`: shared
modules, the `loncothad` profile, Disko, Home Manager, the CachyOS kernel
overlay, `overlays.default`, and `system.stateVersion` `26.05`. Extra modules
come from `nixos/hosts/<name>`. Directories under `nixos/hosts/` that are not
listed there are sketches.

## NixOS

`nixos/modules/default.nix` is the reusable set: `preferences/` (opt-in
`preferences.*.enable`), `user-profiles/` (the option, no users turned on),
`self-hosted/` (opt-in native and OCI service modules), and always-on
hardware/policy modules. Self-hosted containers share a private Podman network;
see `nixos/modules/self-hosted/README.md` for the service inventory and secret
contracts.

This flake's systems also import
`nixos/modules/user-profiles/by-name/loncothad.nix`.

`host.profile` (`nixos/modules/profile.nix`) is how a host declares purpose,
ISA (`hardware.architecture`), x86-64 psABI level (`hardware.x86_64Level`),
chassis (`hardware.formFactor`), and sched_ext policy. CachyOS kernels apply
only on x86_64. Laptops use `scx_rusty`, desktops `scx_bpfland`, WSL
`scx_rustyland`. Leave the profile off on a throwaway VM unless you want that
stack.

Nix daemon settings live in `nixos/modules/preferences/nix.nix`. The package
is **Lix**. Do not add CppNix-only experimental features
(`configurable-impure-env`, `impure-env`).

Login is greetd + tuigreet (`nixos/modules/greetd-tuigreet.nix`, TOML at
`/etc/tuigreet/config.toml`). The tuigreet user-menu UID window must stay
below `ids.uids.nixbld` (30000) or `nixbld*` accounts appear in the list.

## Users and Home Manager

`users.profiles.<name>` (`nixos/modules/user-profiles/default.nix`) creates
`users.users.<name>` when enabled and assigns `home-manager.users.<name>`
from `homeManagerConfig`. `users.mutableUsers` defaults to false.

`loncothad` is enabled on this flake's systems and points at
`home-manager/users/loncothad`. Slim a host with `lib.mkForce` on
`users.profiles.loncothad.homeManagerConfig`.

HM is opted in per host with `preferences.home-manager.enable`
(`useGlobalPkgs`, `useUserPackages`, `extraSpecialArgs.inputs`).

User tree: `default.nix` is the desktop profile and packages; `settings/` is
programs. `home.stateVersion` is `26.05`. Shared HM modules sit in
`home-manager/modules/` (barrel) or in `flakes/` when they are large enough
to be their own flake.

## Nested flakes

Complex Home Manager modules live in `flakes/<name>/` as flake-parts flakes
(`flake.nix`, `flake-parts.nix`, `home-manager.nix`, lockfile). Each exports
`flakeModules.default` (sets `flake.homeModules.<name>`) and
`homeModules.default`.

To consume one from this flake: `path:` input with `nixpkgs` / `flake-parts`
follows, import `inputs.<name>.flakeModules.default` from
`flake-parts/default.nix`, and import the module file from the HM barrel so
`homeModules.default` stays self-contained. A nested flake does not have to
be a core input; the barrel can import `home-manager.nix` alone.

## Niri

NixOS enablement is `nixos/modules/preferences/niri.nix`. The user config is
`home-manager/users/loncothad/settings/gui/niri/`: shared binds/layout in
`config.kdl` (`include "host-settings.kdl"`), outputs and host-only bits in
`by-hostname/<hostname>.kdl`, concatenated by `default.nix`. Desktop helpers
use systemd user units, not niri `spawn-at-startup`.

## Disko and packages

Disk layouts live in `disko/configurations/` and are exported from
`disko/default.nix`. Hosts import Disko through the shared NixOS module list.

Pinned pi npm packages live in `pkgs/pi-extensions/sources.json`. The overlay
exposes `pkgs.piExtensions.<name>`. Refresh with `just pi-extensions-update`.

## Conventions

- Prefer `preferences.*` / `host.profile` / `users.profiles` over ad-hoc copies.
- Host-specific hardware, greetd, and niri output names stay in
  `nixos/hosts/<name>` and `…/niri/by-hostname/<hostname>.kdl`.
- Shared behavior goes in `nixos/modules` or `home-manager/modules`; complex
  HM modules go in `flakes/`.
- Scripts under `misc/scripts/` are Nushell with a JSON BOM (see `AGENTS.md`).
- Recipes belong in the `justfile`, not as one-off documented `nix` commands.
}
