# Wine4Office adapter

This flake packages [Wine4Office](https://github.com/ttv20/wine4office), whose
upstream repository does not provide a Nix flake. It follows the package
adapter shape defined in the [project-flake architecture](../README.md).

## Project links

- Original repository: [ttv20/wine4office](https://github.com/ttv20/wine4office)
- Documentation:
  [upstream documentation directory](https://github.com/ttv20/wine4office/tree/main/documentation)

## Source and outputs

`wine4office-src` is a non-flake input pinned to the upstream
`wine4office-v0.1.11-rc.2` tag. The adapter currently supports `x86_64-linux`
and exports:

```text
packages.x86_64-linux.wine4office
packages.x86_64-linux.wine4office-wine
packages.x86_64-linux.default
apps.x86_64-linux.default
overlays.default
```

The default package and app run Wine4Office. `wine4office-wine` is the patched
Wine build used by that application.

## Files and root integration

- `package.nix` assembles the Wine4Office application.
- `wine.nix` builds the project-specific Wine package.
- `nix-managed-updates.patch` adapts upstream update handling to a Nix-managed
  installation.
- `flake-parts.nix` connects both packages, the app, and the overlay.

The root consumes this directory as the `wine4office` path input. Its package
set is available unchanged below `pkgs.fromFlakes.wine4office`.

## Updating

Adjust the `wine4office-src` tag in `flake.nix`, refresh this flake's lock, and
update source or dependency hashes in the package definitions when moving
releases. Re-check the local patch against upstream before refreshing the root
lock.
