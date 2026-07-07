{
  lib,
  config,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.preferences.audio;
in
{
  options = {
    preferences.audio = {
      enable = mkEnableOption "Audio setup";

      bluetooth = {
        enable = mkEnableOption "Bluetooth setup";
      };
    };
  };

  config = mkIf cfg.enable {
    # Realtime priority for low-latency audio processing
    security.rtkit = {
      enable = true;
      args = [
        "--max-realtime-priority=20"
        "--min-nice-level=-10"
        "--rttime-msec-max=200"
      ];
    };

    networking.firewall.allowedUDPPorts = [
      6001
      6002
    ];

    # Pipewire setup
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;

      wireplumber = mkIf cfg.bluetooth.enable {
        # Disable dynamic headset switching during active mic sessions
        "10-bluetooth-policy" = {
          "wireplumber.settings" = {
            "bluetooth.autoswitch-to-headset-profile" = false;
          };
        };

        # Enforce high-fidelity Bluetooth codecs (Pre-configured preferences)
        "51-bluetooth-codecs" = {
          "monitor.bluez.properties" = {
            "bluez5.codecs" = [
              "ldac"
              "aptx_hd"
              "aac"
              "sbc_xq"
            ];
          };
        };

        # Hardware synchronization controls
        "52-bluetooth-hw-tweaks" = {
          "monitor.bluez.rules" = [
            {
              matches = [ { "device.name" = "~bluez_card.*"; } ];
              actions = {
                update-props = {
                  "bluez5.enable-hw-volume" = true;
                };
              };
            }
          ];
        };
      };
    };

    hardware.bluetooth = mkIf cfg.bluetooth.enable {
      enable = true;
      powerOnBoot = mkDefault true;
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
          Experimental = true;
          FastConnectable = true;
          DiscoverableTimeout = 0;
          PairableTimeout = 0;
        };
        Policy = {
          AutoEnable = true;
          ReconnectAttempts = 7;
          ReconnectInterval = 2;
        };
      };
    };

    systemd.user.services.mpris-proxy = mkIf cfg.bluetooth.enable {
      description = "MPRIS proxy (media controls over bluetooth)";
      wantedBy = [ "default.target" ];
      after = [
        "network.target"
        "sound.target"
      ];
      requires = [ "dbus.service" ];
      path = [ pkgs.bluez ];
      script = "mpris-proxy";
    };

    services.blueman.enable = mkIf cfg.bluetooth.enable true;

    environment.systemPackages = lib.mkMerge [
      (lib.mkIf cfg.enable (with pkgs; [
        wireplumber
        pulsemixer
        pamixer
        pipewire
        lxqt.pavucontrol-qt
        easyeffects
      ]))
      (lib.mkIf cfg.bluetooth.enable (with pkgs; [
        bluez
        bluetuith
      ]))
    ];
  };
}
