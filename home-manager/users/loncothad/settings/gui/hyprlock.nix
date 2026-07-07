{ inputs, ... }:

{
  programs.hyprlock = {
    enable = true;

    settings = {
      general = {
        disable_loading_bar = true;
        hide_cursor = true;
        grace = 5;
      };

      backgrounds = [
        {
          path = inputs.self + "${/misc/assets/wallpapers/blue-waves-dark-background.jpg}";
          blur_passes = 3;
          blur_size = 8;
        }
      ];

      input-fields = [
        {
          size = "250, 60";
          outline_thickness = 2;
          dots_size = 0.2;
          dots_spacing = 0.2;
          fade_on_empty = false;
          placeholder_text = "Enter Password...";
          inner_color = "rgba(17, 17, 27, 0.75)";
          font_color = "rgb(205, 214, 244)";
          outer_color = "rgb(137, 180, 250)";
          check_color = "rgb(249, 226, 175)";
          fail_color = "rgb(243, 139, 168)";
        }
      ];
    };
  };
}
