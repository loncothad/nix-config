{
  lib,
  stdenvNoCC,
  fetchurl,
  nodejs,
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
    nativeBuildInputs = [ nodejs ];
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = npmDepsHash;

    buildPhase = ''
      runHook preBuild
      export HOME="$TMPDIR"
      npm install --omit=dev --ignore-scripts --no-audit --no-fund
      runHook postBuild
    '';
  }
)
