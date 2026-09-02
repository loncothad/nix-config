# ZCode adapter

This flake keeps the official Z.AI graphical and terminal coding helpers
together. `zcode.nix` wraps Z.AI's official Linux AppImage, and
`coding-helper.nix` packages the official `@z_ai/coding-helper` npm release.
It follows the multi-concern adapter shape defined in the
[project-flake architecture](../README.md).

## Project links

- ZCode website: [ZCode](https://zcode.z.ai/en)
- Desktop installation: [Install ZCode](https://zcode.z.ai/en/docs/install)
- Coding Tool Helper documentation: [Coding Tool Helper](https://docs.z.ai/devpack/extension/coding-tool-helper)
- MCP documentation: [ZCode MCP](https://zcode.z.ai/en/docs/mcp-services)
- Terminal package: [@z_ai/coding-helper](https://www.npmjs.com/package/@z_ai/coding-helper)

No unofficial ZCode terminal client is packaged by this adapter.

## Outputs and root integration

The adapter supports `x86_64-linux` and exports:

```text
packages.x86_64-linux.zcode
packages.x86_64-linux.coding-helper
packages.x86_64-linux.default
overlays.default
homeModules.default
```

The root consumes this directory as the `zcode-adapter` path input, mirrors
both packages below `pkgs.fromFlakes.zcode-adapter`, exposes flat `zcode` and
`coding-helper` package outputs, and enables `programs.zcode` in loncothad's
Home Manager profile.

The Home Manager module projects shared `programs.mcp.servers` declarations to
`~/.agents/mcp.json`, a compatibility path documented and loaded by ZCode. A
native `~/.zcode/cli/config.json` containing MCP servers takes precedence over
that file, so MCP entries created in ZCode's settings panel must be merged or
removed if the declarative shared list should remain authoritative.

## Updating

Update the ZCode versioned AppImage URL and SHA-256 in `zcode.nix`. Update the
Coding Tool Helper version and integrity hash in `coding-helper.nix`, refresh
the minimal npm lock in `coding-helper/`, and replace `npmDepsHash` when its
dependency graph changes. Then run `./tasks.nu update-adapter zcode` and build
both root package outputs.
