# Zvec-grep adapter

This flake packages [zvec-grep](https://github.com/zvec-ai/zvec-grep), whose
upstream repository does not provide a Nix flake. It follows the package
adapter shape defined in the [project-flake architecture](../README.md).

## Project links

- Original repository and website: [zvec-ai/zvec-grep](https://github.com/zvec-ai/zvec-grep)
- Documentation: [upstream guides](https://github.com/zvec-ai/zvec-grep/tree/main/docs)
- CLI guide: [docs/02-cli.md](https://github.com/zvec-ai/zvec-grep/blob/main/docs/02-cli.md)

## Source and outputs

`zvec-grep-src` is a non-flake input pinned to the upstream `v0.2.1` tag. The
adapter supports `x86_64-linux` and exports:

```text
packages.x86_64-linux.zvec-grep
packages.x86_64-linux.default
overlays.default
```

`package.nix` builds the TypeScript CLI with Node.js and patches the bundled
native zvec, ripgrep, image-processing, and CPU/Vulkan local-model dependencies
for NixOS. Inapplicable musl and CUDA variants are removed from the closure. The
resulting package exposes the `zg` command.

The root consumes this directory as the `zvec-grep-adapter` path input, mirrors
the package as `pkgs.fromFlakes.zvec-grep-adapter.zvec-grep`, exposes the flat
`packages.x86_64-linux.zvec-grep` convenience output, and installs it in
loncothad's Home Manager profile.

## Updating

Adjust the `zvec-grep-src` tag in `flake.nix`, run
`./tasks.nu update-adapter zvec-grep`, and replace `npmDepsHash` in
`package.nix` when the npm dependency graph changes. Build the nested and root
package outputs after refreshing the locks.
