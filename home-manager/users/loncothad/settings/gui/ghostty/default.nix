{ pkgs, lib, ... }:

{
  programs.ghostty = {
    enable = true;

    settings = {
      theme = "Catppuccin Mocha";
      font-family = "Lilex";
      font-size = 12;
      command = "${lib.getExe pkgs.nushell}";
      window-decoration = false;
      confirm-close-surface = false;
    };
  };
}
