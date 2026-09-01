# xwayland-satellite module adapter

This flake supplies a reusable Home Manager service module for
[xwayland-satellite](https://github.com/Supreeeme/xwayland-satellite). The
package already exists in nixpkgs, so this directory follows the module-only
shape defined in the [project-flake architecture](../README.md) and does not
package upstream.

## Project links

- Original repository:
  [Supreeeme/xwayland-satellite](https://github.com/Supreeeme/xwayland-satellite)
- Documentation:
  [upstream README](https://github.com/Supreeeme/xwayland-satellite/blob/main/README.md)

## Outputs

The adapter declares the Linux and Darwin systems listed in `flake.nix` and
exports:

```text
flakeModules.default
homeModules.default
homeModules.xwayland-satellite
```

The Home Manager module defines `services.xwayland-satellite`, uses
`pkgs.xwayland-satellite` by default, sets `DISPLAY`, and manages a user systemd
service for the graphical session.

## Root integration

The root consumes this directory as the `xwayland-satellite` path input and
imports `flakeModules.default`, which contributes the named Home Manager
module. The default Home Manager barrel also imports `home-manager.nix`
directly so it remains self-contained.

## Updating

There is no project source pin or package hash in this adapter. Update its lock
when its flake framework inputs change. Package versions follow the nixpkgs pin
used by the consumer; service behavior belongs in `home-manager.nix`.
