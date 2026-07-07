{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.nixos-compatibility;

  baseLibraries = with pkgs; [
    stdenv.cc.cc
    glibc

    llvmPackages.llvm
    llvmPackages.libclang
    ncurses

    openssl
    zlib
    curl
    attr
    bzip2
    libffi
    libxml2
    gnutar
    xz

    glib
    util-linux
    dbus

    libgit2
  ];

  # Graphical interface stacks (X11, Wayland, Fonts)
  guiLibraries = with pkgs; [
    # Graphics API
    libGL

    # Wayland core
    wayland
    libxkbcommon

    # X11 fallback
    # xorg.libX11
    # xorg.libXext
    # xorg.libXrender
    # xorg.libXrandr
    # xorg.libXi
    # xorg.libXtst

    # Typography
    fontconfig
    freetype
  ];
in
{
  options = {
    nixos-compatibility = {
      enable = mkEnableOption "global compatibility layer for unpatched binaries";

      enableGUI = mkOption {
        type = types.bool;
        default = false;
        description = "Include Wayland, X11, and core graphics/font libraries in nix-ld.";
      };
    };
  };

  config = mkIf cfg.enable {
    services.envfs.enable = true;

    programs.nix-ld = {
      enable = true;
      libraries = baseLibraries ++ (optionals cfg.enableGUI guiLibraries);
    };
  };
}
