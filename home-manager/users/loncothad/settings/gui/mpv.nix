{ pkgs, ... }:

{
  programs.mpv = {
    enable = true;
    xdgIntegration.enable = true;

    # mpv.conf key-value overrides
    config = {
      vo = "gpu";
      gpu-api = "vulkan"; # FIXME: make it optional depending on hardware configuration?
      hwdec = "auto-safe";

      keep-open = "yes";

      alang = "eng,rus,ru";
      slang = "eng,rus,ru";

      sub-auto = "fuzzy";

      sub-font = "IBM Plex Sans";
      sub-font-size = 38;
      sub-border-size = 2;
      sub-color = "1.0/1.0/1.0/1.0";
      sub-border-color = "0.0/0.0/0.0/1.0";
    };

    scripts = with pkgs.mpvScripts; [
      mpris
      uosc
      thumbfast
      visualizer
      webtorrent-mpv-hook
    ];
  };
}
