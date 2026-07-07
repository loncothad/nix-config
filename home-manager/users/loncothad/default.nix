{ pkgs, ... }:

{
  # TODO: disable GUI apps when we don't need GUI

  imports = [
    ../../modules
    ./settings
  ];

  profile.desktop = {
    enable = true;
    mainDisplay = "eDP-1";

    xkb = {
      layout = "us,ru";
      options = [
        "grp:ralt_toggle"
        "compose:rctrl"
      ];
    };

    displays."eDP-1" = {
      resolution = {
        width = 2880;
        height = 1800;
      };
      refreshRate = 120;
      scale = "1.5";
    };
  };

  programs.ghostty = {
    enable = true;
    systemd.enable = true;
  };

  programs.ashell = {
    enable = true;
    systemd.enable = true;
  };

  programs.zed-editor = {
    enable = true;
    defaultEditor = true;
  };

  programs.pidgin = {
    enable = true;
  };

  programs.fuzzel = {
    enable = true;
  };

  services.polkit-agent-lxqt = {
    enable = true;
  };

  home.packages = with pkgs; [
    playerctl
    mediainfo
    qpwgraph
    beets
    xdg-utils
    brillo

    hyprpicker

    lxqt.pavucontrol-qt
    bitwarden-cli
    bitwarden-desktop
    keepassxc # used as a secrets service too
    davinci-resolve
    telegram-desktop
    brave
    zathura
    pcmanfm-qt
    qdirstat
    onlyoffice-desktopeditors
  ];
}
