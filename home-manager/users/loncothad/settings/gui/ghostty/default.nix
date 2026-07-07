{ pkgs, lib, ... }:

{
  programs.ghostty = {
    enable = true;

    settings = {
      theme = "dark:catppuccin-mocha,light:catppuccin-latte";
      font-family = "Lilex";
      font-size = 12;
      command = "${lib.getExe pkgs.nushell}";
      window-decoration = false;
      confirm-close-surface = false;
    };
  };
}
