{ pkgs, ... }:

{
  users.profiles.loncothad = {
    enable = true;

    description = "huh?";
    shell = pkgs.nushell;
    homeManagerConfig = ../../../../home-manager/users/loncothad;
  };
}
