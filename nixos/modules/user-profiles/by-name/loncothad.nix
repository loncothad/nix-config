{ pkgs, inputs, ... }:

{
  users.users.loncothad.linger = true;

  users.profiles.loncothad = {
    enable = true;

    description = "loncothad";
    shell = pkgs.nushell;
    homeManagerConfig = inputs.self + "/home-manager/users/loncothad";
    authorizedKeys = [
      (inputs.self + "/misc/ssh-keys/id_ed25519_sk_653.pub")
      (inputs.self + "/misc/ssh-keys/id_ed25519_sk_863.pub")
    ];
  };
}
