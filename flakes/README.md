# Project flakes

This directory contains independently evaluable flakes that adapt an external
project to this repository. It is the concrete architecture reference for
`flakes/`; the root [architecture document](../ARCHITECTURE.md) only describes
the boundary between project flakes and the rest of the repository.

## When a project belongs here

Create an adapter here only when at least one of these conditions holds:

1. The local integration directly consumes an external flake or Git
   repository. An upstream repository without a flake is therefore pinned as a
   non-flake input here; an upstream flake may be wrapped when the adapter
   modifies or extends its outputs.
2. The integration owns more than one concern that must travel together, such
   as package repair plus a Home Manager module or reusable modules for both
   NixOS and Home Manager.

A single NixOS or Home Manager module that uses a nixpkgs package, an OCI
image, or a caller-provided package belongs in the corresponding main module
directory. An upstream flake consumed without local adaptation is a direct root
input. Neither case gets a directory here.

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

- `<project>` is the adapter directory name.
- `<project>-adapter` is its local path input name in the root flake.
- `<project>-upstream` is an external flake consumed by the adapter.
- `<source-name>-src` is a non-flake upstream Git input.
- `<flake-provided-package>` is exactly an attribute exported from the
  adapter's `packages.<system>` output.

Root configurations address imported packages as:

```nix
pkgs.fromFlakes.<project>-adapter.<flake-provided-package>
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

### Upstream-flake adapter

Use this shape only when local integration needs to modify or extend an
upstream flake. Name that nested input `<name>-upstream`, preserve relevant
upstream outputs, and keep every related local concern in the adapter. For
example, a repaired package and its Home Manager module are exported together
as `packages`, `overlays.default`, and `homeModules.default`.

### Container-service adapter

Use this shape when a project without a flake publishes an OCI service stack
instead of a package built by Nix:

```text
flakes/<name>/
  README.md
  flake.nix
  flake-parts.nix
  nixos.nix
  flake.lock
```

Track the deployment repository as a `flake = false` source input so changes
to its images, environment, storage, and routing remain reviewable against a
specific revision. The adapter exports `nixosModules.default`, a stable named
`nixosModules.<name>`, and `flakeModules.default`; it does not invent a package
or overlay for container images.

Container services follow the shared
`virtualisation.oci-containers.namedContainers` runtime in this repository.
Their module must expose image overrides, bind to loopback by default, keep
secrets in runtime environment files, declare persistent volumes and service
ordering, and make direct firewall exposure opt-in.

## Root wiring

A core local adapter is added to root `flake.nix` as a path input:

```nix
inputs.example-adapter = {
  url = "path:./flakes/<name>";
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.flake-parts.follows = "flake-parts";
};
```

Then wire only the boundaries the adapter exports:

- mirror `inputs.<name>-adapter.packages.${system}` at
  `pkgs.fromFlakes.<name>-adapter` in `pkgs/default.nix`;
- import and re-export NixOS modules in `flake-parts/modules.nix` and compose
  them in `nixos/default.nix` or the root default NixOS module;
- import Home Manager implementations in `home-manager/modules/default.nix`
  so the default barrel remains self-contained;
- import `inputs.<name>-adapter.flakeModules.default` in
  `flake-parts/default.nix` when the root should expose the adapter's named
  module outputs.

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
