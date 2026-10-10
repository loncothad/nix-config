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

      templates.git_push_bookmark = ''"loncothad/push-" ++ change_id.short()'';

      remotes.origin.auto-track-bookmarks = "*";
    };
  };
}
