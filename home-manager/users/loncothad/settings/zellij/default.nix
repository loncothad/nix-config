{ ... }:

{
  programs.zellij = {
    enable = true;

    settings = {
      theme = "catppuccin-mocha";
      default_layout = "compact";
      pane_frames = false;
    };
  };
}
