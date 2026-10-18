{
  gcc-unwrapped,
  lib,
  patchelf,
  stdenv,
  upstreamPackage,
}:

upstreamPackage.overrideAttrs (old: {
  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ patchelf ];

  postFixup = (old.postFixup or "") + ''
    patchelf \
      --set-interpreter ${stdenv.cc.bintools.dynamicLinker} \
      --set-rpath ${
        lib.makeLibraryPath [
          gcc-unwrapped.lib
          stdenv.cc.libc
        ]
      } \
      "$out/libexec/smolvm/containerd-shim-smolvm-v2"
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    ${stdenv.cc.bintools.dynamicLinker} --list \
      "$out/libexec/smolvm/containerd-shim-smolvm-v2"
    runHook postInstallCheck
  '';
})
