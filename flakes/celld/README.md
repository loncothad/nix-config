# Celld adapter

This flake packages [Celld](https://github.com/denoland/celld), whose upstream
repository does not provide a Nix flake, and exports its NixOS service module.
It follows the package-and-module shape defined in the
[project-flake architecture](../README.md).

## Project links

- Original repository: [denoland/celld](https://github.com/denoland/celld)
- Website: [celld.dev](https://celld.dev/)
- Documentation: [celld.dev/docs](https://celld.dev/docs/)

## Source and outputs

`celld-src` is a non-flake input pinned to the upstream `v0.4.0` tag. The
adapter currently supports `x86_64-linux` and exports:

```text
packages.x86_64-linux.celld
packages.x86_64-linux.default
overlays.default
nixosModules.default
```

The NixOS module defines `services.celld`. Its `package` option defaults to the
package built by this flake, so the module is usable independently of the root
repository overlay.

## Files and root integration

- `package.nix` builds the upstream Rust workspace package.
- `nixos.nix` defines the service, network, storage, credentials, and systemd
  options.
- `flake-parts.nix` connects the source, package, overlay, and module outputs.

The root consumes this directory as the `celld-adapter` path input. Its package
is available as `pkgs.fromFlakes.celld-adapter.celld`, and its module is
re-exported as `nixosModules.celld` and included in the root default NixOS
module.

## Updating

Adjust the `celld-src` tag in `flake.nix`, refresh this flake's lock, and update
the release-archive hash in `package.nix` when moving releases. Evaluate the
nested flake before refreshing the root lock.
