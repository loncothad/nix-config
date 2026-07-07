{ pkgs, ... }:

{
  programs.pidgin = {
    enable = true;

    plugins = with pkgs; [
      pidginPackages.pidgin-otr
    ];
  };
}
