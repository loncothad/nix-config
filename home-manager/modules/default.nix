{ ... }:

{
  imports = [
    ./agents
    ./autolith.nix
    ./brave-xdg.nix
    ./gtk-prefer-dark-theme.nix
    ./qt-dark-theme.nix
    ./mpv-xdg.nix
    ./mutable-config-files.nix
    ./notesnook.nix
    ./nushell-bom.nix
    ./polkit-agent-lxqt.nix
    ./profile.nix
    ./qimgv-xdg.nix
    ./wayland-compatibility.nix
    ./xdg-dbus-proxy.nix
    ./xdg-mime-apps.nix
    ./xwayland-satellite.nix
    ./mark-shot.nix
    ./zellij-daemon.nix
    ./debloat.nix
  ];
}
