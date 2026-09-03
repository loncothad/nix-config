# Rust + Bazel workspace

This template provides a Cargo workspace with a reusable library crate and a
binary crate built by Bazel through
[`rules_rust`](https://github.com/bazelbuild/rules_rust). The Rust toolchain used
by Bazel is hermetic and pins Rust 1.98.1. The Nix development shell tracks the
latest stable Cargo, rustc, rustfmt, Clippy, rust-analyzer, and Rust sources from
[`rust-overlay`](https://github.com/oxalica/rust-overlay) for editor support and
familiar local workflows. Nix provides Bazelisk, and `.bazelversion` pins the
active Bazel 9 LTS release used locally and in CI.

Initialize a repository and enter its development shell:

```console
nix flake init -t github:loncothad/nix-config#rust-bazel
nix develop
```

Build, test, and run the workspace:

```console
bazel build //...
bazel test //...
bazel run //crates/cli:workspace-cli -- Rust
```

Add another crate under `crates/`, list it in the root `Cargo.toml`, and give it
a `BUILD.bazel` file. Internal Bazel dependencies use labels such as
`//crates/greeting`; Cargo uses the matching path dependency.

Cargo remains the source of truth for workspace membership and editor tooling,
while each `BUILD.bazel` explicitly mirrors internal path dependencies. When
you add third-party crates, configure the current
[`crate_universe` Bzlmod extension](https://bazelbuild.github.io/rules_rust/crate_universe_bzlmod.html)
to generate their Bazel targets from `Cargo.toml` and `Cargo.lock`. This layout
keeps the useful workspace split described in
[Tweag's Rust workspace guide](https://www.tweag.io/blog/2023-07-27-building-rust-workspace-with-bazel/),
while replacing its older `WORKSPACE` setup with Bzlmod.

The included GitHub Actions workflow installs Nix, evaluates the flake, and
runs formatting plus the Cargo and Bazel test suites inside `nix develop`.
