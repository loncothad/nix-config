{ ... }:

{
  imports = [
    ./bottom.nix
    ./btop.nix
    ./git.nix
    ./ssh.nix
    ./jj.nix
    ./openai-codex.nix
    ./tldr.nix
    ./zoxide.nix
    ./zcode.nix
    ./zvec-grep.nix

    ./autolith
    ./nushell
    ./zellij

    ./gui/mark-shot.nix
    ./gui/fastpotify.nix
    ./gui/mpv.nix
    ./gui/obs.nix
    ./gui/pidgin.nix
    ./gui/zed.nix
    ./gui/ghostty

    ./gui/quickshell

    ./gui/ashell.nix
    ./gui/fuzzel.nix
    ./gui/hyprlock.nix
    ./gui/hyprpaper.nix
    ./gui/niri
  ];
}
