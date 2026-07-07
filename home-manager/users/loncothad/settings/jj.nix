# jj tui
#

{ pkgs, ... }:

{
  home.packages = with pkgs; [
    watchman
  ];

  programs.jujutsu = {
    enable = true;

    settings = {
      user = {
        name = "loncothad";
        email = "loncothad@gmail.com";
      };

      ui = {
        editor = "hx";
        default-command = "log";

        # difftastic is integration is handled in the difftastic module
      };

      git = {
        auto-local-branch = true;
        push-bookmark-prefix = "loncothad/push-";
      };
    };
  };
}
