{ pkgs, inputs, ... }:

{
  users.profiles.loncothad = {
    enable = true;

    description = "loncothad";
    shell = pkgs.nushell;
    homeManagerConfig = inputs.self + "/home-manager/users/loncothad";
    authorizedKeys = [
      (inputs.self + "/misc/ssh-keys/id_072.pub")
      (inputs.self + "/misc/ssh-keys/id_365.pub")
    ];
  };
}
