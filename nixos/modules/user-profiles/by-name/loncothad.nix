{ pkgs, inputs, ... }:

{
  users.profiles.loncothad = {
    enable = true;

    description = "loncothad";
    shell = pkgs.nushell;
    homeManagerConfig = inputs.self + "/home-manager/users/loncothad";
  };
}
