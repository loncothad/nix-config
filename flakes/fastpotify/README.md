# Fastpotify adapter

This flake keeps the repository's package repair and Home Manager integration
for [Fastpotify](https://github.com/crmne/fastpotify) together. Upstream
already exports a flake; the local adapter consumes it as
`fastpotify-upstream`, preserves its package set, and replaces the Fastpotify
derivation with the repaired build used by this configuration.

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

The package output adds the native libraries required by the desktop client,
uses a repository-owned Cargo vendor hash, and corrects projectM's library
search path. The Home Manager module defines `programs.fastpotify`; the
standalone `homeModules.default` output defaults its package to this flake's
repaired build.

The root consumes this directory as the `fastpotify-adapter` path input and
exposes the package as
`pkgs.fromFlakes.fastpotify-adapter.fastpotify`. The raw module implementation
is imported by the root Home Manager barrel, where callers provide that package
explicitly.

## Updating

Update `fastpotify-upstream`, refresh this flake's lock, and replace the Cargo
vendor hash when the dependency graph changes. Evaluate this flake before
refreshing the root lock.
