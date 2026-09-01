# Project flakes

This directory contains independently evaluable flakes that adapt an external
project to this repository. It is the concrete architecture reference for
`flakes/`; the root [architecture document](../ARCHITECTURE.md) only describes
the boundary between project flakes and the rest of the repository.

## When a project belongs here

Use one of these integration paths:

1. An upstream project with a usable `flake.nix` is a direct root input. Do not
   wrap its packages in another local flake.
2. An upstream project without a flake gets a package adapter here. Its source
   is a non-flake input of that adapter, and its package and project-specific
   modules stay together.
3. A reusable module for a native-flake or nixpkgs project may use a
   module-only adapter here. It does not duplicate the upstream package.

Every directory has a `README.md` explaining which case it implements, its
outputs, its root integration, and how its upstream pin is updated. It also
links the original repository, upstream documentation, and a separate project
website when one exists.

## Common contract

Every adapter is a flake-parts flake with its own lock:

```text
flakes/<flake-name>/
  README.md          role, outputs, root wiring, and update notes
  flake.nix          inputs, supported systems, and flake-parts entry
  flake-parts.nix    complete public output definitions
  flake.lock         independently reproducible input graph
```

Optional implementation files are named by what they provide:

```text
  package.nix        primary package derivation
  <package>.nix      additional package derivation
  nixos.nix          NixOS module implementation
  home-manager.nix   Home Manager module implementation
  *.patch            patches owned by the adapter
```

The entry point must use `flake-parts.lib.mkFlake`; the output definition file
is always `flake-parts.nix`. Core `path:` inputs follow the root `nixpkgs` and
`flake-parts`, while the nested lock keeps the adapter usable by itself.

Names have distinct meanings:

- `<flake-name>` is the directory and root input name.
- `<source-name>-src` is a non-flake upstream source input.
- `<flake-provided-package>` is exactly an attribute exported from the
  adapter's `packages.<system>` output.

Root configurations address imported packages as:

```nix
pkgs.fromFlakes.<flake-name>.<flake-provided-package>
```

The root overlay preserves the entire package set under the flake name. It
never promotes imported packages to top-level `pkgs`; flat aliases are allowed
only in the root `packages` output for command-line convenience.

## Definition shapes

### Package adapter

Use this shape when upstream has no flake:

```text
flakes/<name>/
  README.md
  flake.nix
  flake-parts.nix
  package.nix
  flake.lock
```

`flake.nix` pins `inputs.<name>-src` with `flake = false`.
`flake-parts.nix` passes that input to `package.nix` and exports:

```text
packages.<system>.<package>
packages.<system>.default
overlays.default
```

Additional packages and `apps.default` are allowed when they are part of the
same project. The overlay must produce the same named package set as
`packages.<system>` (apart from the convenience `default` alias).

### Package and module adapter

Add `nixos.nix` and/or `home-manager.nix` beside the package when this
repository owns service or program integration for the same non-flake
upstream. In addition to the package outputs, export the reusable module as:

```text
nixosModules.default
homeModules.default
```

A module must expose a `package` option. Its default is closed over the
adapter's own `packages` output, so importing the module does not require the
root `fromFlakes` overlay.

### Module-only adapter

Use this shape when the package comes from nixpkgs or a separate native flake:

```text
flakes/<name>/
  README.md
  flake.nix
  flake-parts.nix
  home-manager.nix   # or nixos.nix
  flake.lock
```

The adapter exports both the directly consumable module and a flake-parts
module that contributes the stable named output:

```text
flakeModules.default
homeModules.default
homeModules.<name>   # contributed by flakeModules.default
```

Use the corresponding `nixosModules` names for a NixOS-only adapter. The
service/program module uses `lib.mkPackageOption` when nixpkgs owns the package,
or requires an explicit package when a separate upstream flake owns it.

## Root wiring

A package-producing local adapter is added to root `flake.nix` as a path input:

```nix
inputs.<name> = {
  url = "path:./flakes/<name>";
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.flake-parts.follows = "flake-parts";
};
```

Then wire only the boundaries the adapter exports:

- mirror `inputs.<name>.packages.${system}` at
  `pkgs.fromFlakes.<name>` in `pkgs/default.nix`;
- import and re-export NixOS modules in `flake-parts/modules.nix` and compose
  them in `nixos/default.nix` or the root default NixOS module;
- import Home Manager implementations in `home-manager/modules/default.nix`
  so the default barrel remains self-contained;
- import `inputs.<name>.flakeModules.default` in `flake-parts/default.nix` when
  the root should expose the adapter's named module outputs.

A module-only adapter may be barrel-only when the root does not need it as an
input. It remains independently evaluable, while the relevant root barrel
imports its implementation file directly.

## Updating and validation

For a new adapter, add its files to Git before Nix evaluates the path. Then
lock the adapter first and the root second:

```console
git add flakes/<name>
nix flake lock ./flakes/<name>
nix flake lock
```

For an existing non-flake source, update the source input in the nested flake,
then refresh the root lock after verifying any source or dependency hashes.
Use the repository command surface for validation:

```console
just show
just check
just host=kepler eval-host
just build-package <package>
```

Run the commands relevant to the changed outputs; package-only documentation
changes do not require a host build.
