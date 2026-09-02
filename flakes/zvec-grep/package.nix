{
  autoPatchelfHook,
  buildNpmPackage,
  lib,
  source,
  stdenv,
  vulkan-loader,
}:

let
  package = lib.importJSON "${source}/package.json";
in
buildNpmPackage {
  pname = "zvec-grep";
  inherit (package) version;

  src = source;
  npmDepsHash = "sha256-pc04qzhnYaS0xpQAYwN6HEG8oPEqoBIBMVKC1OZ0L+8=";
  ONNXRUNTIME_NODE_INSTALL_CUDA = "skip";

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [
    stdenv.cc.cc.lib
    vulkan-loader
  ];

  postInstall = ''
    packageRoot="$out/lib/node_modules/@zvec/zvec-grep/node_modules"

    rm -rf \
      "$packageRoot/@node-llama-cpp/linux-x64-cuda" \
      "$packageRoot/@node-llama-cpp/linux-x64-cuda-ext" \
      "$packageRoot/@reflink/reflink-linux-x64-musl" \
      "$packageRoot/@zvec/bindings-linux-x64-musl" \
      "$packageRoot/@img/sharp-linuxmusl-x64" \
      "$packageRoot/@img/sharp-libvips-linuxmusl-x64"
  '';

  passthru.upstreamSource = source;

  meta = {
    inherit (package) description;
    homepage = "https://github.com/zvec-ai/zvec-grep";
    license = lib.licenses.asl20;
    mainProgram = "zg";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryNativeCode
    ];
  };
}
