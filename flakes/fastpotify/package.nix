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
    hash = "sha256-e/uJwqYszz7ASo5elWcTIX6Smb0xJgQZA5fgHuwvzaE=";
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
    substituteInPlace \
      "$cargoDepsCopy/source-git-1/projectm-sys-1.2.3/build.rs" \
      --replace-fail \
      'println!("cargo:rustc-link-search=native={}/lib", dst.display());' \
      'println!("cargo:rustc-link-search=native={}/lib64", dst.display());'
  '';
})
