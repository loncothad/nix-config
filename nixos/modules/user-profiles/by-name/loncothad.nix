{ pkgs, inputs, ... }:

{
  users.users.loncothad.linger = true;

  users.profiles.loncothad = {
    enable = true;

    description = "loncothad";
    shell = pkgs.nushell;
    homeManagerConfig = inputs.self + "/home-manager/users/loncothad";
    authorizedKeys = [ inputs.loncothad-ssh-keys.outPath ];
  };
}
