{ ... }:

{
  imports = [
    ./brave-xdg.nix
    ./gtk-prefer-dark-theme.nix
    ./qt-dark-theme.nix
    ./mpv-xdg.nix
    ./nushell-bom.nix
    ./polkit-agent-lxqt.nix
    ./profile.nix
    ./qimgv-xdg.nix
    ./wayland-compatibility.nix
    ./xwayland-satellite.nix
    ../../flakes/mark-shot/home-manager.nix
    ../../flakes/pi/home-manager.nix
    ./debloat.nix
  ];
}
