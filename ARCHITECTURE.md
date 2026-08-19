# Architecture

Personal NixOS + Home Manager flake. Systems are composed from shared modules;
per-host and per-user files only carry differences.

## Layout

```
flake.nix                 inputs + flake-parts entry
flake-parts/default.nix   systems, formatter, flake outputs
nixos/                    NixOS systems, modules, hosts
home-manager/             HM modules and user trees
disko/                    disk layouts (referenced from NixOS)
pkgs/                     local packages
misc/                     scripts, ssh keys, assets
justfile                  repo recipes (rebuild, eval, niri, git)
```

## Flake outputs

Defined in `flake-parts/default.nix`:

- `nixosConfigurations` — from `nixos/default.nix`
- `formatter` — `pkgs.nixfmt`
- `diskoConfigurations` — from `disko/`
- `nixosModules` / `homeModules` — currently empty placeholders

`nixos/default.nix` builds each host with `mkNixOsSystem`:

- always imports `nixos/modules`, Disko, Home Manager, and the CachyOS kernel overlay
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

`nixos/modules/default.nix` is imported by every system. It pulls in:

- `preferences/` — optional feature modules (`preferences.*.enable`)
- `user-profiles/` — declarative users + HM attachment
- always-on hardware/policy modules (debloat, greetd-tuigreet, profile, …)

`host.profile` (`nixos/modules/profile.nix`) selects desktop vs other purposes
and the CachyOS / sched_ext kernel path. Kepler enables it; a VM or server
should leave it off.

Nix daemon settings live in `nixos/modules/preferences/nix.nix`. The configured
`nix.package` is **Lix**. Do not add CppNix-only experimental features
(`configurable-impure-env`, `impure-env`).

## Users and Home Manager

`users.profiles.<name>` (`nixos/modules/user-profiles/default.nix`):

- creates `users.users.<name>` when `enable = true`
- assigns `home-manager.users.<name>` from `homeManagerConfig`
- `users.mutableUsers` defaults to false

`loncothad` is enabled globally via
`nixos/modules/user-profiles/by-name/loncothad.nix` and points at
`home-manager/users/loncothad`. Override `homeManagerConfig` with `lib.mkForce`
if a host needs a slim home.

HM is opted in per host with `preferences.home-manager.enable`
(`useGlobalPkgs`, `useUserPackages`, `extraSpecialArgs.inputs`).

User tree:

```
home-manager/users/loncothad/default.nix   desktop profile + packages
home-manager/users/loncothad/settings/     programs (git, niri, helix, …)
home-manager/modules/                      shared HM modules
```

`home.stateVersion` is `26.05`.

## Niri

- NixOS: `nixos/modules/preferences/niri.nix` (`programs.niri.enable`)
- HM: `home-manager/users/loncothad/settings/gui/niri/`
  - `config.kdl` — shared binds/layout (`include "host-settings.kdl"`)
  - `by-hostname/<hostname>.kdl` — outputs and host-only spawn
  - `default.nix` concatenates the host KDL with generated autostart
    (xwayland-satellite, hyprpaper, ashell, quickshell)

Login is greetd + tuigreet (`nixos/modules/greetd-tuigreet.nix`, TOML at
`/etc/tuigreet/config.toml`). The tuigreet user menu UID window must stay
below `ids.uids.nixbld` (30000) or `nixbld*` accounts appear in the list.

## Disko

Layouts in `disko/configurations/`. `disko/default.nix` currently exports
`kepler`. Hosts import Disko via the shared NixOS module list.

## Conventions

- Prefer `preferences.*` / `host.profile` / `users.profiles` over ad-hoc copies
- Host-specific hardware and greetd/niri output names stay in `nixos/hosts/<name>`
- KDL for niri: `focus-ring { on }`, no top-level `preferences { }`, no
  duplicate keybinds
- Git HM config uses `programs.git.settings` (not `extraConfig`). URL rewrites
  must be `url."git@github.com:"` so the generated INI is
  `[url "git@github.com:"]`
- The flake is git-tracked: `nix` only sees files `git add`ed
