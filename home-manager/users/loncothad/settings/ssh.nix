{ inputs, ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
  };

  home.file.".ssh/github.pub".source = inputs.loncothad-ssh-keys.outPath;
}
