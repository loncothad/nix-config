{ ... }:

{
  imports = [
    ./android.nix
    ./audio.nix
    ./core.nix
    ./freesm-launcher.nix
    ./home-manager.nix
    ./lanzaboote.nix
    ./luks.nix
    ./networking.nix
    ./nix.nix
    ./podman.nix
    ./agenix.nix

    ./gui/fonts.nix
    ./gui/plymouth.nix
  ];
}

# envfs # services.envfs.enable = true;
# nix-ld

# sbctl
# pciutils
# lshw
# usbutils
# hwinfo
# sdparm
# hdparm
# smartmontools
# nvme-cli
# gptfdisk
# parted
# efibootmgr
# efivar
# ddrescue
# ms-sys
# testdisk
# ffmpeg
# btop
# iotop
# iftop
# netstat
# powertop
# bat
# lsof
# psmisc
# moreutils
# socat
# inetutils
# iproute2
# fuse # programs.fuse.enable
# vulkan-tools
# i18n.defaultLocale = "C.UTF-8";
# disable gnupg
# mopidy
# libva-utils
# clinfo
# fastfetch

# environment.sessionVariables = {
#     XKB_DEFAULT_LAYOUT = "us,ru";
#     XKB_DEFAULT_OPTIONS =
#       "grp:lctrl_toggle,grp_led:caps,ctrl:nocaps,compose:ralt";
#     LANG = lib.mkOverride 99 "C.UTF-8";
#     LC_ALL = lib.mkOverride 99 "C.UTF-8";
#     XCOMPOSEFILE = "${config.home-manager.users.balsoft.xdg.configHome}/XCompose";
#   };

#   i18n.defaultLocale = "C.UTF-8";

#   time.timeZone = "Europe/Madrid";
#   home-manager.users.balsoft = {
#     home.language = let
#       C = "C.UTF-8";
#       ru = "ru_RU.UTF-8";
#     in {
#       address = C;
#       monetary = C;
#       paper = ru;
#       time = C;
#       base = C;
#     };
#   };

# services = {
#     dbus.implementation = "broker";
#     openssh = {
#       enable = true;
#       settings = {
#         PermitRootLogin = lib.mkDefault "no";
#         PasswordAuthentication = false;
#         KbdInteractiveAuthentication = false;
#       };
#     };
#     tailscale.enable = true;
#     fwupd.daemonSettings.EspLocation = config.boot.loader.efi.efiSysMountPoint;
#   };

# systemd = {
#     oomd = {
#       enable = true;
#       enableRootSlice = true;
#       enableUserSlices = true;
#     };
#     network.wait-online.anyInterface = true;
#   };

# nix.settings = {
#     download-buffer-size = lib.mkDefault 268435456; # 256MiB
#     max-substitution-jobs = lib.mkDefault 32;
#   };

# console = {
#     font = lib.mkDefault "ter-v24n";
#     keyMap = lib.mkDefault "us";
#     packages = with pkgs; [ terminus_font ];
#   };

# Shared nix settings for NixOS and Darwin
# { lib, pkgs, ... }:
# let
#   inherit (pkgs.stdenv) isDarwin;
# in
# {
#   nix = lib.mkMerge [
#     {
#       package = pkgs.nixVersions.latest;
#       settings = {
#         accept-flake-config = true;
#         allowed-users = [ "@wheel" ];
#         build-users-group = "nixbld";
#         builders-use-substitutes = true;
#         trusted-users = [
#           "root"
#           "@wheel"
#         ];
#         substituters = [
#           "https://nix-config.cachix.org"
#           "https://nix-community.cachix.org"
#         ];
#         trusted-public-keys = [
#           "nix-config.cachix.org-1:Vd6raEuldeIZpttVQfrUbLvXJHzzzkS0pezXCVVjDG4="
#           "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
#         ];
#         cores = 0;
#         max-jobs = "auto";
#         experimental-features = [
#           "auto-allocate-uids"
#           "configurable-impure-env"
#           "flakes"
#           "nix-command"
#         ];
#         connect-timeout = 5;
#         http-connections = 32;
#         flake-registry = "/etc/nix/registry.json";
#         always-allow-substitutes = true;
#         impure-env = [ "NIXPKGS_ALLOW_UNFREE" ];
#       };

#       distributedBuilds = true;
#       extraOptions = ''
#         !include tokens.conf
#       '';
#     }

#     # NixOS-specific (use optionalAttrs to avoid defining non-existent options)
#     (lib.optionalAttrs (!isDarwin) {
#       settings = {
#         auto-optimise-store = true;
#         sandbox = true;
#       };
#       channel.enable = false;
#       daemonCPUSchedPolicy = "batch";
#       daemonIOSchedPriority = 5;
#       optimise = {
#         automatic = true;
#         dates = [ "03:00" ];
#       };
#     })

#     # Darwin-specific (use optionalAttrs to avoid defining non-existent options)
#     (lib.optionalAttrs isDarwin {
#       settings = {
#         # Causes annoying "cannot link ... to ...: File exists" errors on Darwin
#         auto-optimise-store = false;
#         sandbox = false;
#       };
#       daemonIOLowPriority = false;
#     })
#   ];
# }

# Shared nix registry configuration
# Works for NixOS, Darwin, and home-manager (all have nix.registry option)
# { flake, ... }:
# let
#   inherit (flake) inputs;
# in
# {
#   nix.registry = {
#     nixpkgs.flake = inputs.nixpkgs;
#     p.flake = inputs.nixpkgs;
#   };
# }

# enable zswap
