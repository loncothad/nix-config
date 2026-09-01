# Fastpotify adapter

This flake keeps the repository's necessary package repair and Home Manager
integration for [Fastpotify](https://github.com/crmne/fastpotify) together.
Upstream already exports a flake; the local adapter consumes it as
`fastpotify-upstream`, preserves its package set, and replaces its Fastpotify
derivation with the repaired build.

## Project links

- Original repository: [crmne/fastpotify](https://github.com/crmne/fastpotify)
- Website and documentation: [fastpotify.rocks](https://fastpotify.rocks/)
- Repository documentation: [upstream README](https://github.com/crmne/fastpotify#readme)

## Outputs

The adapter currently supports `x86_64-linux` and exports:

```text
packages.x86_64-linux.fastpotify
packages.x86_64-linux.default
overlays.default
homeModules.default
```

`package.nix` supplies the missing Cargo vendor hash and native desktop
libraries, and corrects projectM's library search path. The Home Manager module
defines `programs.fastpotify`; the standalone `homeModules.default` output
defaults its package to the repaired build exposed by this flake.

The root consumes this directory as the `fastpotify-adapter` path input and
exposes the package as
`pkgs.fromFlakes.fastpotify-adapter.fastpotify`. The raw module implementation
is imported by the root Home Manager barrel, where callers provide that package
explicitly.

## Updating

Update `fastpotify-upstream`, refresh this flake's lock, and replace the Cargo
vendor hash when the dependency graph changes. Evaluate and build this flake
before refreshing the root lock.
