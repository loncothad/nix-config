# mark-shot module adapter

This flake supplies a reusable Home Manager module for
[mark-shot](https://github.com/jswysnemc/mark-shot). Upstream already provides
the package as a native flake, so this directory follows the module-only shape
defined in the [project-flake architecture](../README.md) and does not package
the application again.

## Project links

- Original repository: [jswysnemc/mark-shot](https://github.com/jswysnemc/mark-shot)
- Documentation:
  [upstream documentation directory](https://github.com/jswysnemc/mark-shot/tree/main/docs)

## Outputs

The adapter declares the Linux and Darwin systems listed in `flake.nix` and
exports:

```text
flakeModules.default
homeModules.default
homeModules.mark-shot
```

The Home Manager module defines `programs.mark-shot`, installs its required
`package`, and can generate `config.json` and `extensions.json` from the
`settings` and `extensions` options.

## Root integration

The root tracks mark-shot upstream directly as the `mark-shot` input and
mirrors its package set at `pkgs.fromFlakes.mark-shot`. This local adapter is
barrel-only: `home-manager/modules/default.nix` imports `home-manager.nix`
directly, while the user's configuration supplies the upstream package to the
module.

## Updating

There is no project source pin in this adapter. Update its lock only when its
flake framework inputs change. Application updates belong to the root
`mark-shot` input; module changes belong in `home-manager.nix`.
