{ pkgs, lib, ... }:

{
  programs.ghostty = {
    enable = true;

    settings = {
      theme = "dark:Catppuccin Mocha,light:Catppuccin Latte";
      font-family = "Lilex";
      font-size = 12;
      command = "${lib.getExe pkgs.nushell}";
      window-decoration = false;
      confirm-close-surface = false;
    };
  };
}
