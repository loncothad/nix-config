{ lib, pkgs, ... }:

{
  programs.git = {
    enable = true;
    lfs.enable = true;

    ignores = [
      # Backups and swap files
      "*~"
      "*.swp"
      "*.swo"

      # Node & Build structures
      "node_modules/"
      "dist/"
      "build/"

      # Environment configurations
      ".env"
      ".envrc"
      ".direnv/"

      # OS metadata
      ".DS_Store"
    ];

    settings = {
      user = {
        name = "loncothad";
        email = "loncothad@gmail.com";
      };

      init = {
        defaultBranch = "main";
      };

      pull = {
        rebase = true;
      };

      push = {
        autoSetupRemote = true;
      };

      core = {
        autocrlf = "input";
        whitespace = "space-before-tab";
        fsmonitor = true;
        untrackedCache = true;
      };

      safe = {
        directory = "*";
      };

      # Must be url."git@github.com:" so toGitINI emits [url "git@github.com:"]
      # (a colon after the closing quote is invalid git-config syntax).
      url."git@github.com:" = {
        insteadOf = "https://github.com/";
      };
    };
  };

  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      prompt = "enabled";
    };
  };

  programs.lazygit = {
    enable = true;

    settings = {
      gui = {
        showIcons = true;
        borderStyle = "rounded";
      };
      git = {
        paging = {
          colorArg = "always";
          pager = "${pkgs.delta}/bin/delta --dark --paging=never";
        };
      };
    };
  };

  programs.difftastic = {
    enable = true;

    git = {
      enable = true;
      diffToolMode = true;
    };

    jujutsu = {
      enable = true;
    };

    options = {

    };
  };

  home.sessionVariables = {
    DFT_DISPLAY = "inline"; # difftastic mode
  };

  programs.delta = {
    enable = true;

    enableGitIntegration = lib.mkForce false;
    enableJujutsuIntegration = lib.mkForce false;
  };

  programs.git-credential-oauth = {
    enable = true;
  };

  programs.git-cliff = {
    enable = true;
  };

  home.packages = with pkgs; [
    gitu
  ];
}
