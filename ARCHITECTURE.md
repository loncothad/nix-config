# Architecture

This repository composes NixOS systems, Home Manager profiles, packages, and
project integrations from one flake-parts root. Boundaries are chosen so a new
host, user, module, or upstream project can be added without changing an
unrelated layer.

## Repository layers

```
flake.nix                 root inputs and flake-parts entry
flake-parts/              root outputs and composition
flakes/<project>/         independently locked project adapters
nixos/modules/            repository-owned reusable NixOS behavior
nixos/hosts/<name>/       host-specific composition and hardware
home-manager/modules/     repository-owned reusable Home Manager behavior
home-manager/users/<name> user profiles and settings
pkgs/                     root overlay composition
disko/                    reusable disk layouts
misc/                     scripts, keys, and assets
justfile                  supported command surface
```

The root exports `nixosConfigurations`, `nixosModules`, `homeModules`,
`overlays`, and `packages`. Files in `flake-parts/` define those outputs;
feature code belongs in the layer that owns it rather than in the output
wiring.

## Project integration boundary

External projects with usable upstream flakes are direct inputs. Packaging for
an upstream without a flake, along with modules specific to that project, lives
in an independently locked adapter under `flakes/`. Reusable module-only
adapters may also live there when nixpkgs or a separate native flake owns the
package.

The root overlay mirrors package-producing inputs without flattening them:

```
pkgs.fromFlakes.<flake-name>.<flake-package-name>
```

The root `packages` output may provide convenient flat entry points, but NixOS
and Home Manager configuration uses the two-level `fromFlakes` namespace.

The concrete adapter layouts, output contracts, and root wiring are maintained
in [`flakes/README.md`](./flakes/README.md).

## NixOS composition

`nixos/default.nix` constructs systems from these inputs:

- repository-owned modules from `nixos/modules/`;
- NixOS modules exported by project flakes;
- the selected host under `nixos/hosts/`;
- shared upstream modules such as Home Manager and Disko;
- the root overlay and host-specific overlays;
- enabled user profiles.

`nixos/modules/default.nix` is a barrel for repository-owned behavior only.
Project-owned modules stay with their adapter and are composed at the system or
root-export boundary.

The currently constructed systems are `kepler` and `vega-small`. A directory
under `nixos/hosts/` becomes a system only when `nixos/default.nix` lists it.

## Home Manager composition

`home-manager/modules/default.nix` is the reusable repository module set.
Project adapters may also export Home Manager modules; the root `homeModules`
output combines named project modules with the repository default barrel.

`users.profiles.<name>` connects a NixOS user to a Home Manager configuration.
The currently enabled profile is `loncothad`, sourced from
`home-manager/users/loncothad/`. Host-specific reductions override that
profile instead of putting host policy into shared user modules.

## Host and desktop boundaries

Reusable policy belongs in `nixos/modules/` or `home-manager/modules/`.
Hardware and host choices belong in `nixos/hosts/<name>/`. Niri's shared
configuration lives under the user profile, while output-specific fragments
live in `niri/by-hostname/<hostname>.kdl`.

Disk layouts are independent values under `disko/configurations/` and are
selected by system composition. Scripts are Nushell programs under
`misc/scripts/` with their package dependencies declared in BOM comments.

## Extension flow

- New host: add its directory, then list it in `nixos/default.nix`.
- New repository feature: add a reusable module and import it from the relevant
  barrel.
- New native-flake project: add the input and mirror its package set under
  `pkgs.fromFlakes.<input>`.
- New non-flake project: follow the package-adapter contract in
  `flakes/README.md`, then wire its exported packages and modules at the root
  boundaries.
- New user-facing choice: keep the reusable option in a module and enable it in
  the user's settings tree.

Operational commands and repository invariants are defined in `AGENTS.md` and
the `justfile`.
