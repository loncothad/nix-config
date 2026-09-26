{
  lib,
  rustPlatform,
  source,
}:

let
  manifest = builtins.fromTOML (builtins.readFile "${source}/Cargo.toml");
in
rustPlatform.buildRustPackage {
  pname = "cargo-multivers";
  inherit (manifest.package) version;
  src = source;
  cargoLock.lockFile = "${source}/Cargo.lock";
  # Upstream integration tests run nested Cargo builds that depend on ambient Cargo configuration.
  doCheck = false;

  meta = {
    description = "Build portable binaries with CPU-specific variants";
    homepage = "https://github.com/ronnychevalier/cargo-multivers";
    license = lib.licenses.mit;
    mainProgram = "cargo-multivers";
    platforms = [ "x86_64-linux" ];
  };
}
