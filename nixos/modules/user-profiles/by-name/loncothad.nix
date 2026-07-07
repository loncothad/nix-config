{ pkgs, inputs, ... }:

{
  users.profiles.loncothad = {
    enable = true;

    description = "huh?";
    shell = pkgs.nushell;
    homeManagerConfig = inputs.self + "/home-manager/users/loncothad";
  };
}
