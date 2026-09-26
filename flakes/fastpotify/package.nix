{
  lib,
  libx11,
  libxcursor,
  libxi,
  libxkbcommon,
  libxrandr,
  rustPlatform,
  upstreamPackage,
  upstreamSource,
  wayland,
}:

upstreamPackage.overrideAttrs (oldAttrs: {
  cargoDeps = rustPlatform.fetchCargoVendor {
    pname = "fastpotify";
    version = (lib.importTOML "${upstreamSource}/Cargo.toml").package.version;
    src = upstreamSource;
    hash = "sha256-RpYSZhnJw4del+yyjnF0ax+cPUIAJNwGljdVmoyEphs=";
  };

  buildInputs = (oldAttrs.buildInputs or [ ]) ++ [
    libx11
    libxcursor
    libxi
    libxkbcommon
    libxrandr
    wayland
  ];

  postPatch = (oldAttrs.postPatch or "") + ''
    projectmBuildScript=$(find "$cargoDepsCopy" -path '*/projectm-sys-*/build.rs' -print -quit)
    test -n "$projectmBuildScript"
    substituteInPlace \
      "$projectmBuildScript" \
      --replace-fail \
      '.define("BUILD_TESTING", "OFF")' \
      '.define("BUILD_TESTING", "OFF")
            .define("CMAKE_INSTALL_LIBDIR", "lib")
            .define("ENABLE_DEBUG_POSTFIX", "OFF")'
  '';
})
