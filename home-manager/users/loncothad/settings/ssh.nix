{ inputs, ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
  };

  home.file = {
    ".ssh/id_ed25519_sk_653.pub".source = inputs.self + "/misc/ssh-keys/id_ed25519_sk_653.pub";
    ".ssh/id_ed25519_sk_863.pub".source = inputs.self + "/misc/ssh-keys/id_ed25519_sk_863.pub";
  };
}
