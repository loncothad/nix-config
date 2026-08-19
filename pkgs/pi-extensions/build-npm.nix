{
  lib,
  stdenvNoCC,
  fetchurl,
  nodejs,
  cacert,
}:

{
  pname,
  version,
  hash,
  npmName ? pname,
  npmDepsHash ? null,
}:

let
  tarballBase = lib.last (lib.splitString "/" npmName);
in
stdenvNoCC.mkDerivation (
  {
    inherit pname version;

    src = fetchurl {
      url = "https://registry.npmjs.org/${npmName}/-/${tarballBase}-${version}.tgz";
      inherit hash;
    };

    # npm pack always uses a top-level package/ directory.
    sourceRoot = "package";

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -a . "$out/"
      runHook postInstall
    '';

    meta = {
      description = "Pi coding-agent package ${npmName}";
      homepage = "https://www.npmjs.com/package/${npmName}";
    };
  }
  // lib.optionalAttrs (npmDepsHash != null) {
    nativeBuildInputs = [
      nodejs
      cacert
    ];
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = npmDepsHash;
    # Keep the tree identical to `nix hash path` from the updater.
    dontFixup = true;

    env = {
      SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
      NODE_EXTRA_CA_CERTS = "${cacert}/etc/ssl/certs/ca-bundle.crt";
    };

    buildPhase = ''
      runHook preBuild
      export HOME="$TMPDIR"
      npm install --omit=dev --ignore-scripts --no-audit --no-fund
      runHook postBuild
    '';
  }
)
