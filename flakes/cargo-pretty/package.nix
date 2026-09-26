{
  lib,
  rustPlatform,
  source,
}:

let
  manifest = builtins.fromTOML (builtins.readFile "${source}/Cargo.toml");
in
rustPlatform.buildRustPackage {
  pname = "cargo-pretty";
  inherit (manifest.package) version;
  src = source;
  cargoLock.lockFile = "${source}/Cargo.lock";

  meta = {
    description = "Cargo build wrapper with a live progress view";
    homepage = "https://github.com/romancitodev/cargo-pretty";
    license = lib.licenses.mit;
    mainProgram = "cargo-pretty";
    platforms = [ "x86_64-linux" ];
  };
}
