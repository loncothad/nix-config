{ ... }:

{
  services.zellij-daemon.enable = true;

  programs.zellij = {
    enable = true;

    settings = {
      theme = "catppuccin-mocha";
      default_layout = "compact";
      pane_frames = false;
      web_sharing = "on";
    };
  };
}
