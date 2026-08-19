{ inputs, ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
  };

  home.file = {
    ".ssh/id_072.pub".source = inputs.self + "/misc/ssh-keys/id_072.pub";
    ".ssh/id_365.pub".source = inputs.self + "/misc/ssh-keys/id_365.pub";
  };
}
