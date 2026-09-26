# cargo-pretty adapter

This flake packages [cargo-pretty](https://github.com/romancitodev/cargo-pretty), a Cargo build, run, and test progress display. Its upstream repository has no Nix flake.

The non-flake `cargo-pretty-src` input pins a revision of upstream's main branch. The crate is named `cargo-pretty-build`; it installs the `cargo-pretty` binary. The adapter exports `packages.x86_64-linux.cargo-pretty`, `packages.x86_64-linux.default`, and `overlays.default`. The root mirrors the package at `pkgs.fromFlakes.cargo-pretty-adapter.cargo-pretty` for loncothad's Home Manager profile.

Upstream documentation is in the [README](https://github.com/romancitodev/cargo-pretty#readme); the [crates.io page](https://crates.io/crates/cargo-pretty-build) is its package website. To update, run `./tasks.nu update-adapter cargo-pretty`, then build the package output.
