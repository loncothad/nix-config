{
  lib,
  rustPlatform,
  fetchFromGitHub,
  installShellFiles,
  scdoc,
}:
# nixpkgs-unstable is still 0.9.1 (CLI-only). Kepler's greetd command and
# TOML config need 0.11 (--config, outputs, background). Drop this overlay
# once unstable catches up.
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "tuigreet";
  version = "0.11.0";

  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "tuigreet";
    repo = "tuigreet";
    tag = finalAttrs.version;
    hash = "sha256-4DB4Pl2UwIeab/MJaX3VfVNMsPWE6Q513z1NDdxvG3o=";
  };

  cargoHash = "sha256-5Q4E8nnmQ109gcfxxctn/rne5N4Qvz2Pft6o7as2fSc=";

  nativeBuildInputs = [
    installShellFiles
    scdoc
  ];

  postInstall = ''
    scdoc < contrib/man/tuigreet-1.scd > tuigreet.1
    installManPage tuigreet.1
  '';

  meta = {
    description = "Graphical console greeter for greetd";
    homepage = "https://github.com/tuigreet/tuigreet";
    changelog = "https://github.com/tuigreet/tuigreet/releases/tag/${finalAttrs.version}";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
    mainProgram = "tuigreet";
  };
})
