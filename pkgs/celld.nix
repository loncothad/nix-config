{
  autoPatchelfHook,
  esbuild,
  fetchurl,
  gzip,
  lib,
  makeWrapper,
  stdenv,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "celld";
  version = "0.4.0";

  src = fetchurl {
    url = "https://github.com/denoland/celld/releases/download/v${finalAttrs.version}/celld-x86_64-unknown-linux-gnu.gz";
    hash = "sha256-BIhihZcVRyXbL2H4VDT7OB4bJTXR6fCXxtIHJ80zeXM=";
  };

  dontUnpack = true;

  nativeBuildInputs = [
    autoPatchelfHook
    gzip
    makeWrapper
  ];

  buildInputs = [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"
    gzip -dc "$src" > "$out/bin/celld"
    chmod +x "$out/bin/celld"

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram "$out/bin/celld" \
      --prefix PATH : ${lib.makeBinPath [ esbuild ]}
  '';

  meta = {
    description = "Self-hosted, distributed Durable Objects";
    homepage = "https://celld.dev";
    license = lib.licenses.asl20;
    mainProgram = "celld";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
