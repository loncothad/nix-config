# OpenAI Codex adapter

This flake keeps OpenAI's terminal and desktop coding clients together. The
Codex CLI comes from nixpkgs, while `chatgpt.nix` repackages OpenAI's official
Linux desktop release. It follows the multi-concern adapter shape defined in
the [project-flake architecture](../README.md).

## Project links

- Codex repository: [openai/codex](https://github.com/openai/codex)
- Codex CLI documentation: [Codex CLI](https://learn.chatgpt.com/docs/codex/cli)
- ChatGPT website: [ChatGPT desktop](https://chatgpt.com/features/desktop/)
- Linux documentation: [ChatGPT desktop app for Linux](https://learn.chatgpt.com/docs/linux/linux-app)

## Outputs and root integration

The adapter supports `x86_64-linux` and exports:

```text
packages.x86_64-linux.codex
packages.x86_64-linux.chatgpt
packages.x86_64-linux.default
overlays.default
homeModules.default
```

The root consumes this directory as the `openai-codex-adapter` path input,
mirrors both packages below `pkgs.fromFlakes.openai-codex-adapter`, exposes
flat `codex` and `chatgpt` package outputs, and installs both in loncothad's
Home Manager profile through `programs.openai-codex`. The module uses Home
Manager's native Codex module and enables its integration with shared
`programs.mcp.servers` declarations. The stock Git package remains installed;
the proprietary desktop app may invoke it internally even though
repository-owned commands prefer gix where supported.

## Updating

Update the Codex CLI through the root nixpkgs input. For ChatGPT, read the
official APT `Packages.gz` index, update the versioned package URL and SHA-256
in `chatgpt.nix`, then run `./tasks.nu update-adapter openai-codex`. Build both
root package outputs after refreshing the locks.
