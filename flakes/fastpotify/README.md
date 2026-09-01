# Fastpotify adapter

This flake keeps the upstream package set and this repository's Home Manager
integration for [Fastpotify](https://github.com/crmne/fastpotify) together.
Upstream already exports a flake; the local adapter consumes it as
`fastpotify-upstream` and passes its packages through unchanged.

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

The package and overlay outputs pass through upstream's package set unchanged.
The Home Manager module defines `programs.fastpotify`; the standalone
`homeModules.default` output defaults its package to the upstream Fastpotify
build exposed by this flake.

The root consumes this directory as the `fastpotify-adapter` path input and
exposes the package as
`pkgs.fromFlakes.fastpotify-adapter.fastpotify`. The raw module implementation
is imported by the root Home Manager barrel, where callers provide that package
explicitly.

## Updating

Update `fastpotify-upstream` and refresh this flake's lock. Evaluate this flake
before refreshing the root lock.
