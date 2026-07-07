{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.preferences.core;
in
{
  options = {
    preferences.core = {
      enable = mkEnableOption "core system preferences";

      timeZone = mkOption {
        type = types.str;
        default = "UTC";
        description = "System timezone setting.";
      };

      defaultLocale = mkOption {
        type = types.str;
        default = "en_US.UTF-8";
        description = "The primary POSIX locale.";
      };

      console = {
        keyMap = mkOption {
          type = types.str;
          default = "ruwin_alt_sh-UTF-8";
          description = "Keyboard layout map for the virtual console (defaults to dual US/RU layout toggled with Alt+Shift).";
        };

        font = mkOption {
          type = types.str;
          default = "ter-v24b";
          description = "Font name for the virtual console.";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    time.timeZone = cfg.timeZone;
    i18n.defaultLocale = cfg.defaultLocale;

    console = {
      keyMap = cfg.console.keyMap;
      font = cfg.console.font;
      packages = [ pkgs.terminus_font ];
    };

    services.dbus.implementation = "broker";

    services.fstrim.enable = true;

    systemd.oomd = {
      enable = mkDefault true;
      enableRootSlice = true;
      enableUserSlices = true;
    };

    environment.systemPackages = with pkgs; [
      moreutils
      fastfetch
      bottom
      btop
      iotop
      iftop
      powertop
      lsof
      psmisc

      ms-sys
      vulkan-tools
      libva-utils
      clinfo
      inetutils
      pciutils
      usbutils
      lshw
      smartmontools
      nvme-cli
      hwinfo
      sdparm
      hdparm
      sbctl
      pam_u2f

      parted
      efibootmgr

      ripgrep
      curl
      git
      nushell
    ];
  };
}
