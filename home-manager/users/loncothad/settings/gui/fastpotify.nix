{ pkgs, ... }:

{
  home.packages = [ pkgs.fromFlakes.fastpotify ];
}
