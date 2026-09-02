{ pkgs, ... }:

{
  home.packages = [ pkgs.fromFlakes.zvec-grep-adapter.zvec-grep ];
}
