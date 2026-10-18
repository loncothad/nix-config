# Spotifast adapter (Fastpotify compatibility)

This flake combines upstream packages and Home Manager integration for
[Spotifast](https://github.com/crmne/spotifast), formerly Fastpotify. It consumes
the upstream flake as `fastpotify-upstream` and preserves its package set.
The adapter directory, input names, `fastpotify` package alias, and
`programs.fastpotify` option remain stable for existing consumers.

## Project links

- Original repository: [crmne/spotifast](https://github.com/crmne/spotifast)
- Website and documentation: [spotifast.rocks](https://spotifast.rocks/)
- Repository documentation: [upstream README](https://github.com/crmne/spotifast#readme)

## Outputs

The adapter currently supports `x86_64-linux` and exports:

```text
packages.x86_64-linux.fastpotify
packages.x86_64-linux.spotifast
packages.x86_64-linux.default
overlays.default
homeModules.default
flakeModules.default
```

Upstream owns the Cargo vendor hash, desktop libraries, projectM library path,
and pinned Rust toolchain. No local package overrides are needed. The Home
Manager module defines `programs.fastpotify` and writes settings below
`$XDG_CONFIG_HOME/spotifast/`; the standalone `homeModules.default` output
defaults its package to the upstream build exposed by this flake.
`flakeModules.default` contributes that module to a consuming root as the named
`homeModules.fastpotify` output.

The root consumes this directory as the `fastpotify-adapter` path input,
exposes the package as `pkgs.fromFlakes.fastpotify-adapter.fastpotify`, imports
the adapter's flake-parts module for its named Home Manager output, and composes
`homeModules.default` for standalone consumers. NixOS-managed profiles receive
the adapter output through `home-manager.sharedModules`.

## Updating

Run `./tasks.nu update-adapter fastpotify`, then validate with
`./tasks.nu check-adapters --no-build` and build the root
`packages.x86_64-linux.fastpotify` output. Upstream maintains dependency hashes.
