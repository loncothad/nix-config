# Architecture

Personal NixOS + Home Manager flake. Systems are composed from shared modules;
per-host and per-user files only carry differences.

Outside consumers can import `nixosModules`, `homeModules`, `overlays`, and
`packages` without taking this flake's hosts or the `loncothad` user.

## Layout

```
flake.nix                 inputs + flake-parts entry
flake-parts/              systems, modules, packages, host wiring
nixos/                    NixOS systems, modules, hosts
home-manager/             HM modules and user trees
disko/                    disk layouts (referenced from NixOS)
pkgs/                     overlay (`piExtensions`) and local packages
misc/                     nushell scripts, ssh keys, assets
justfile                  repo recipes (rebuild, eval, niri, git, pi)
```

## Flake outputs

Defined under `flake-parts/`:

| Output | Source | Notes |
| --- | --- | --- |
| `nixosConfigurations` | `nixos/default.nix` | this flake's hosts |
| `nixosModules.default` | `nixos/modules` | shared NixOS modules, **no** `loncothad` |
| `homeModules.default` | `home-manager/modules` | barrel import of all HM modules |
| `homeModules.<name>` | individual HM modules | `pi`, `xwayland-satellite`, … |
| `overlays.default` | `pkgs/default.nix` | adds `pkgs.piExtensions` |
| `packages.<system>.*` | `pkgs/pi-extensions` | derivations only |
| `formatter` | treefmt-nix (`nixfmt`) | per-system, via `nix fmt` / `just fmt` |
| `diskoConfigurations` | `disko/` | currently `kepler` |

External use:

```nix
# NixOS
imports = [ inputs.nix-config.nixosModules.default ];
nixpkgs.overlays = [ inputs.nix-config.overlays.default ];

# Home Manager
imports = [
  inputs.nix-config.homeModules.default
  # or a single module:
  inputs.nix-config.homeModules.pi
];
```

`nixos/default.nix` builds each host with `mkNixOsSystem`:

- imports `nixos/modules`, the `loncothad` user profile, Disko, Home Manager,
  the CachyOS kernel overlay, and `overlays.default`
- `system.stateVersion` is `26.05`
- host extra modules live under `nixos/hosts/<name>`

Wired hosts today:

| Flake attr   | Path                    | Role                         |
| ------------ | ----------------------- | ---------------------------- |
| `kepler`     | `nixos/hosts/kepler`    | laptop (active desktop)      |
| `vega-small` | `nixos/hosts/vega-small`| extra system                 |

Other directories under `nixos/hosts/` (`aldebaran`, `andromeda`, `janus`,
`polaris`, `rigel`, `vega`) are sketches and are **not** in
`nixosConfigurations` until added to `nixos/default.nix`.

## NixOS composition

`nixos/modules/default.nix` is the reusable module set. It pulls in:

- `preferences/` — optional feature modules (`preferences.*.enable`)
- `user-profiles/` — the `users.profiles.<name>` option (no users enabled)
- always-on hardware/policy modules (debloat, greetd-tuigreet, profile, …)

This flake's systems additionally import
`nixos/modules/user-profiles/by-name/loncothad.nix`.

`host.profile` (`nixos/modules/profile.nix`) selects desktop vs other purposes
and the CachyOS / sched_ext kernel path. Kepler enables it; a VM or server
should leave it off. Desktops use `scx_rusty` (energy-biased); WSL uses
`scx_rustyland`; other roles use `scx_bpfland`.

Nix daemon settings live in `nixos/modules/preferences/nix.nix`. The configured
`nix.package` is **Lix**. Do not add CppNix-only experimental features
(`configurable-impure-env`, `impure-env`).

## Users and Home Manager

`users.profiles.<name>` (`nixos/modules/user-profiles/default.nix`):

- creates `users.users.<name>` when `enable = true`
- assigns `home-manager.users.<name>` from `homeManagerConfig`
- `users.mutableUsers` defaults to false

`loncothad` is enabled on this flake's systems via
`nixos/modules/user-profiles/by-name/loncothad.nix` and points at
`home-manager/users/loncothad`. Override `homeManagerConfig` with `lib.mkForce`
if a host needs a slim home.

HM is opted in per host with `preferences.home-manager.enable`
(`useGlobalPkgs`, `useUserPackages`, `extraSpecialArgs.inputs`).

User tree:

```
home-manager/users/loncothad/default.nix   desktop profile + packages
home-manager/users/loncothad/settings/     programs (git, niri, helix, pi, …)
home-manager/modules/                      shared HM modules (`programs.pi`, …)
```

`home.stateVersion` is `26.05`.

## Niri

- NixOS: `nixos/modules/preferences/niri.nix` (`programs.niri.enable`)
- HM: `home-manager/users/loncothad/settings/gui/niri/`
  - `config.kdl` — shared binds/layout (`include "host-settings.kdl"`)
  - `by-hostname/<hostname>.kdl` — outputs and host-only spawn
  - `default.nix` concatenates the host KDL. Desktop helpers (ashell,
    hyprpaper, quickshell, xwayland-satellite) use systemd user units.

Login is greetd + tuigreet (`nixos/modules/greetd-tuigreet.nix`, TOML at
`/etc/tuigreet/config.toml`). The tuigreet user menu UID window must stay
below `ids.uids.nixbld` (30000) or `nixbld*` accounts appear in the list.

## Disko

Layouts in `disko/configurations/`. `disko/default.nix` currently exports
`kepler`. Hosts import Disko via the shared NixOS module list.

## Pi extensions

Pinned npm packages live in `pkgs/pi-extensions/sources.json`. The overlay
exposes them as `pkgs.piExtensions.<name>`. Refresh with
`just pi-extensions-update`.

## Conventions

- Prefer `preferences.*` / `host.profile` / `users.profiles` over ad-hoc copies
- Host-specific hardware and greetd/niri output names stay in `nixos/hosts/<name>`
- Scripts under `misc/scripts/` are Nushell with a JSON BOM (see `AGENTS.md`)
