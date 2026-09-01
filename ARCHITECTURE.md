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
tasks.nu                  supported Nushell command surface
```

The root exports `nixosConfigurations`, `nixosModules`, `homeModules`,
`overlays`, and `packages`. Files in `flake-parts/` define those outputs;
feature code belongs in the layer that owns it rather than in the output
wiring.

## Project integration boundary

An integration gets an independently locked adapter under `flakes/` only when
it directly consumes an external flake or Git repository, or when it owns more
than one integration concern that must travel together. Package repair plus a
module, a package plus both NixOS and Home Manager modules, and a pinned
non-flake source plus a deployment module all meet that boundary.

A single repository-owned NixOS or Home Manager module stays in the respective
main module directory when it uses nixpkgs or accepts its package from the
caller. An upstream project with a usable flake is a direct root input when the
root only consumes its existing outputs. Local path inputs use the
`<project>-adapter` suffix so they cannot be mistaken for native upstream
flakes.

The root overlay mirrors package-producing inputs without flattening them:

```
pkgs.fromFlakes.<input-name>.<flake-package-name>
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
Simple project modules are repository-owned behavior and live in this barrel.
Modules stay with an adapter only when the integration crosses the project
adapter boundary above; those modules are composed at the system or root-export
boundary.

Rootful application containers are expressed as Podman Quadlets through
`quadlet-nix`. `nixos/modules/containers.nix` owns the declarative
`selfhosted.network` resource and auto-update policy; individual project
modules own their Quadlet container resources and dependencies. The public
project configuration remains grouped under
`virtualisation.oci-containers.namedContainers`, while generated runtime
resources live under `virtualisation.quadlet`.

The currently constructed systems are `kepler` and `vega-small`. A directory
under `nixos/hosts/` becomes a system only when `nixos/default.nix` lists it.

## Home Manager composition

`home-manager/modules/default.nix` is the reusable repository-owned module set.
Project adapters may also export Home Manager modules when they meet the
adapter boundary. Adapter outputs are composed through Home Manager shared
modules for NixOS profiles. The root `homeModules.default` combines those
adapter outputs with the repository barrel for standalone consumers, while
named outputs expose each module independently.

`users.profiles.<name>` connects a NixOS user to a Home Manager configuration.
The currently enabled profile is `loncothad`, sourced from
`home-manager/users/loncothad/`. Host-specific reductions override that
profile instead of putting host policy into shared user modules.

Global agent configuration uses the vendor-neutral `agents` Home Manager
schema. It owns the canonical XDG tree of global instructions, system prompts,
named prompts, skills, and supporting files. Agent harness integrations consume
that schema or its published directories and own any vendor-specific discovery
paths; the shared module does not encode a particular harness's layout. The
`AGENTS_HOME` session variable points to the canonical tree.

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
- New upstream project consumed as-is: add its native flake input and mirror
  its package set under `pkgs.fromFlakes.<input>`.
- New project adapter: first apply the boundary above, then follow the concrete
  contract in `flakes/README.md` and wire its exported packages and modules at
  the root boundaries.
- New user-facing choice: keep the reusable option in a module and enable it in
  the user's settings tree.

Operational commands and repository invariants are defined in `AGENTS.md` and
`tasks.nu`.
