# cargo-multivers adapter

This flake packages [cargo-multivers](https://github.com/ronnychevalier/cargo-multivers), a Cargo subcommand for portable binaries with CPU-specific variants. Its upstream repository has no Nix flake.

The non-flake `cargo-multivers-src` input pins the upstream `v0.13.0` tag. The adapter exports `packages.x86_64-linux.cargo-multivers`, `packages.x86_64-linux.default`, and `overlays.default`. The root mirrors the package at `pkgs.fromFlakes.cargo-multivers-adapter.cargo-multivers` for loncothad's Home Manager profile.

Upstream documentation is in the [README](https://github.com/ronnychevalier/cargo-multivers#readme); the [crates.io page](https://crates.io/crates/cargo-multivers) is its package website. To update, change the source tag and run `./tasks.nu update-adapter cargo-multivers`, then build the package output.
