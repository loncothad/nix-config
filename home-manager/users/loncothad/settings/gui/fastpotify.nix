{ pkgs, ... }:

{
  programs.fastpotify = {
    enable = true;
    package = pkgs.fromFlakes.fastpotify-adapter.fastpotify;
  };
}
