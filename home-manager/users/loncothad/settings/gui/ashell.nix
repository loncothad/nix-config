{ pkgs, ... }:

{
  home.packages = with pkgs; [
    playerctl
    pavucontrol
    networkmanagerapplet
  ];

  programs.ashell = {
    enable = true;

    settings = {
      language = "en-US";

      position = "Top";
      outputs = "Active";

      enable_esc_key = true;

      modules = {
        left = [
          "Workspaces"
        ];
        center = [
          "WindowTitle"
        ];
        right = [
          "SystemInfo"
          "MediaPlayer"
          [
            "Tray"
            "Tempo"
            "Privacy"
            "Settings"
          ]
        ];
      };

      workspaces = {
        visibility_mode = "MonitorSpecific";
        disable_special_workspaces = true;
      };

      system_info = {
        indicators = [
          "Cpu"
          "Memory"
        ];
        interval = 10;
      };

      tray = {
        right_click = "Menu";
      };

      tempo = {
        clock_format = "%H:%M %Y-%m-%d";
        timezones = [ "Europe/Moscow" ];

        weather_indicator = "None";
      };

      notifications = {
        format = "%H:%M";
      };

      settings = {
        hibernate_cmd = "systemctl hibernate";
        battery_hide_when_full = true;
        peripheral_indicators.Specific = [ "Gamepad" ];
        audio_indicator_format = "IconAndPercentage";
      };

      osd = {
        enabled = true;
        timeout = 750;
      };

      animations = {
        enabled = true;
      };

      appearance = {
        bar.surface = "solid";
        font_name = "Lilex";
      };
    };
  };
}
