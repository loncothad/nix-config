{ inputs, pkgs }:
let
  inherit (pkgs) lib;
  fixture = inputs.nixpkgs.lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    modules = [
      ../nixos/modules/apparmor-profiles.nix
      {
        nixpkgs.config.allowUnfree = true;
        security.apparmor.namedProfiles = {
          enable = true;
          brave.enable = true;
          pidgin.enable = true;
          telegram.enable = true;
          _64gram.enable = true;
          zed.enable = true;
          neovim.enable = true;
          helix.enable = true;
          qimgv.enable = true;
          mpv.enable = true;
          ghostty.enable = true;
        };
      }
    ];
  };
  profiles = pkgs.linkFarm "apparmor-audit-profiles" (
    lib.mapAttrsToList (name: policy: {
      inherit name;
      # Compile textual attachments without building the attached applications.
      path = pkgs.writeText name (builtins.unsafeDiscardStringContext policy.profile);
    }) fixture.config.security.apparmor.policies
  );
  parser = "${pkgs.apparmor-parser}/bin/apparmor_parser";
  includes = "${pkgs.apparmor-profiles}/etc/apparmor.d";
in
pkgs.runCommand "apparmor-configuration-checks" { } ''
  mkdir -p $out
  for profile in ${profiles}/*; do
    ${parser} --config-file /dev/null --skip-kernel-load --skip-cache \
      --features-file ${includes}/abi/5.0 --Include ${includes} "$profile" \
      > "$out/$(basename "$profile").log" 2>&1
  done
''
