{ ... }:

{
  imports = [
    ./autolith.nix
    ./brave-xdg.nix
    ../../flakes/fastpotify/home-manager.nix
    ./gtk-prefer-dark-theme.nix
    ./qt-dark-theme.nix
    ./mpv-xdg.nix
    ./nushell-bom.nix
    ./polkit-agent-lxqt.nix
    ./profile.nix
    ./qimgv-xdg.nix
    ./wayland-compatibility.nix
    ./xdg-dbus-proxy.nix
    ./xwayland-satellite.nix
    ./mark-shot.nix
    ./zellij-daemon.nix
    ./debloat.nix
  ];
}
