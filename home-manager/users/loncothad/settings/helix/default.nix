{ lib, pkgs, ... }:

{
  programs.helix = {
    enable = true;
    defaultEditor = true;

    settings = {
      theme = "autumn_night";

      editor = {
        shell = [
          "nu"
          "-c"
        ];

        line-number = "relative";
        cursorline = true;
        cursorcolumn = true;

        bufferline = "multiple";

        color-modes = true;

        default-line-ending = "lf";

        trim-trailing-whitespace = true;

        statusline = {
          left = [
            "mode"
            "spinner"
            "read-only-indicator"
            "file-modification-indicator"
          ];
          center = [ "file-name" ];
          right = [
            "diagnostics"
            "selections"
            "file-encoding"
          ];

          separator = "│";

          mode = {
            normal = "NOR";
            insert = "INS";
            select = "SEL";
          };
        };

        lsp = {
          enable = true;
          display-messages = true;
          display-progress-messages = true;
          display-inlay-hints = true;
        };

        cursor-shape = {
          normal = "block";
          insert = "bar";
          select = "underline";
        };

        file-picker = {
          hidden = false;
        };

        auto-save = {
          focus-lost = true;
          after-delay = {
            enable = true;
            timeout = 300;
          };
        };

        whitespace = {
          render = {
            space = "all";
            tab = "all";
          };
        };

        indent-guides = {
          # render = true;
          character = "▏";
          # skip-levels = 1;
        };

        soft-wrap = {
          enable = true;
        };

        inline-diagnostics = {
          cursor-line = "warn";
          other-lines = "warn";
        };
      };
    };

    # TODO: https://docs.helix-editor.com/languages.html
    languages = {
      language = [
        {
          name = "nix";
          auto-format = true;
          formatter = {
            command = lib.getExe pkgs.nixfmt;
          };
          language-servers = [ "nixd" ];
        }
      ];

      language-server = {
        nixd = {
          command = lib.getExe pkgs.nixd;
        };
      };
    };
  };
}
