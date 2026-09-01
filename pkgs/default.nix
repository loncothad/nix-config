{ inputs }:

final: _prev:
let
  system = final.stdenv.hostPlatform.system;
  fastpotifyPackages = inputs.fastpotify.packages.${system};
  fastpotify = fastpotifyPackages.fastpotify.overrideAttrs (oldAttrs: {
    cargoDeps = final.rustPlatform.fetchCargoVendor {
      pname = "fastpotify";
      version = (final.lib.importTOML "${inputs.fastpotify}/Cargo.toml").package.version;
      src = inputs.fastpotify;
      hash = "sha256-e/uJwqYszz7ASo5elWcTIX6Smb0xJgQZA5fgHuwvzaE=";
    };
    buildInputs = (oldAttrs.buildInputs or [ ]) ++ [
      final.libx11
      final.libxcursor
      final.libxi
      final.libxrandr
      final.libxkbcommon
      final.wayland
    ];
    postPatch = (oldAttrs.postPatch or "") + ''
      substituteInPlace \
        "$cargoDepsCopy/source-git-1/projectm-sys-1.2.3/build.rs" \
        --replace-fail \
        'println!("cargo:rustc-link-search=native={}/lib", dst.display());' \
        'println!("cargo:rustc-link-search=native={}/lib64", dst.display());'
    '';
  });
in
{
  fromFlakes = {
    agenix = inputs.agenix.packages.${system};
    agenix-rekey = inputs.agenix-rekey.packages.${system};
    autolith = inputs.autolith.packages.${system};
    fastpotify = fastpotifyPackages // {
      default = fastpotify;
      inherit fastpotify;
    };
    mark-shot = inputs.mark-shot.packages.${system};
    wine4office = inputs.wine4office.packages.${system};
  };

  celld = final.callPackage ./celld.nix { };
}
