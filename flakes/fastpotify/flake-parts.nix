{ inputs, ... }:

let
  mkPackages =
    pkgs:
    let
      upstreamPackages = inputs.fastpotify-upstream.packages.${pkgs.stdenv.hostPlatform.system};
      fastpotify = upstreamPackages.fastpotify.overrideAttrs (oldAttrs: {
        cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
          pname = "fastpotify";
          version = (pkgs.lib.importTOML "${inputs.fastpotify-upstream}/Cargo.toml").package.version;
          src = inputs.fastpotify-upstream;
          hash = "sha256-e/uJwqYszz7ASo5elWcTIX6Smb0xJgQZA5fgHuwvzaE=";
        };
        buildInputs = (oldAttrs.buildInputs or [ ]) ++ [
          pkgs.libx11
          pkgs.libxcursor
          pkgs.libxi
          pkgs.libxrandr
          pkgs.libxkbcommon
          pkgs.wayland
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
    upstreamPackages
    // {
      default = fastpotify;
      inherit fastpotify;
    };
in
{
  perSystem =
    { pkgs, ... }:
    {
      packages = mkPackages pkgs;
    };

  flake = {
    overlays.default = final: _prev: mkPackages final;

    homeModules.default =
      { lib, pkgs, ... }:
      {
        imports = [ ./home-manager.nix ];
        programs.fastpotify.package =
          lib.mkDefault
            inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.fastpotify;
      };
  };
}
