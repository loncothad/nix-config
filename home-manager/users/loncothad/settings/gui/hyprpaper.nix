{ ... }:

{
  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = true;
      splash = false;

      wallpaper = [
        {
          monitor = "";
          path = "${../../../../../../misc/assets/wallpapers/blue-waves-dark-background.jpg}";
          fit_mode = "cover";
        }
      ];
    };
  };
}
