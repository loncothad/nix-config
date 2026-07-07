{ ... }:

{
  programs.yazi = {
    enable = true;
    enableNushellIntegration = true;

    settings = {
      mgr = {
        ratio = [
          1
          3
          4
        ];

        show_hidden = true;
        show_symlink = true;

        sort_by = "natural";
        sort_sensitive = false;
        sort_reverse = false;

        linemode = "size_and_btime";
      };
    };

    preview = {
      wrap = "yes";

      tab_size = 2;

      max_width = 1200;
      max_height = 1000;

      image_filter = "lanczos3";
      image_quality = 80;
    };

    opener = {
      edit = [
        {
          run = "hx \"$@\"";
          block = true;
          desc = "Edit in TUI Text Editor";
        }
        {
          run = "zeditor \"$@\"";
          orphan = true;
          desc = "Edit in GUI Text Editor";
        }
      ];

      play = [
        {
          desc = "Play with MPV";
          run = "mpv %s";
          orphan = true;
        }
      ];

      view = [
        {
          run = "qimgv \"$@\"";
          orphan = true;
          desc = "View with Qimgv";
        }
      ];

      open = [
        {
          run = "xdg-open %s1";
          desc = "Open";
        }
      ];
    };

    open = {
      rules = [

      ];
    };
  };
}
