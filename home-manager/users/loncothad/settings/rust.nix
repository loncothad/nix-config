{ pkgs, ... }:

let
  targets = [
    "x86_64-unknown-linux-gnu"
    "x86_64-unknown-linux-musl"
    "aarch64-unknown-linux-gnu"
    "aarch64-unknown-linux-musl"
    "wasm32-unknown-unknown"
    "wasm32-wasip1"
  ];
  extensions = [
    "rust-analyzer"
    "rust-src"
  ];
  stable = pkgs.rust-bin.stable.latest.default.override {
    inherit extensions targets;
  };
  nightly = pkgs.rust-bin.selectLatestNightlyWith (
    toolchain:
    toolchain.default.override {
      inherit extensions targets;
    }
  );
  nightlyCommands = pkgs.symlinkJoin {
    name = "rust-nightly-commands";
    paths =
      map
        (
          command:
          pkgs.writeShellScriptBin "${command}-nightly" ''
            export PATH="${nightly}/bin:$PATH"
            export RUSTC="${nightly}/bin/rustc" RUSTDOC="${nightly}/bin/rustdoc"
            export RUST_SRC_PATH="${nightly}/lib/rustlib/src/rust/library"
            exec "${nightly}/bin/${command}" "$@"
          ''
        )
        [
          "cargo"
          "cargo-clippy"
          "cargo-fmt"
          "rustc"
          "rustdoc"
          "rustfmt"
          "clippy-driver"
          "rust-analyzer"
        ];
  };
in
{
  home.packages = with pkgs; [
    stable
    nightlyCommands
    cargo-zigbuild
    cargo-nextest
    reindeer
    cargo-deny
    fromFlakes.cargo-multivers-adapter.cargo-multivers
    fromFlakes.cargo-pretty-adapter.cargo-pretty
  ];
}
