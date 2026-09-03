{ ... }:

let
  rustBazel = {
    path = ../templates/rust-bazel;
    description = "Multi-crate Rust workspace built with Bazel and rules_rust";
  };
in
{
  flake.templates = {
    default = rustBazel;
    rust-bazel = rustBazel;
  };
}
