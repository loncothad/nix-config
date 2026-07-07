{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.hardware.extraDeviceRules;
in
{
  options.hardware.extraDeviceRules = {
    enable = mkEnableOption "custom udev rules for security keys, keyboards, and microcontrollers";

    yubikeys = mkOption {
      type = types.bool;
      default = true;
    };
    feitian = mkOption {
      type = types.bool;
      default = true;
    };

    keyboards = mkOption {
      type = types.bool;
      default = true;
    };

    microcontrollers = mkOption {
      type = types.bool;
      default = true;
      description = "Enable rules for ESP32, STM32, and RP2040/RP2350 development boards.";
    };
  };

  config = mkIf cfg.enable {
    services.udev.packages =
      (optional cfg.yubikeys pkgs.yubikey-personalization)
      ++ (optional cfg.yubikeys pkgs.libfido2)
      ++ (optional cfg.keyboards pkgs.qmk-udev-rules)
      ++
        # Upstream packages tracking standard SWD/JTAG debuggers
        (optionals cfg.microcontrollers (
          with pkgs;
          [
            openocd # Broad coverage for STM32 (ST-Link), FTDI, J-Link, CMSIS-DAP
            picoprobe-udev-rules # Explicit rules for Raspberry Pi debug probes
            stlink
            platformio-core.udev
            libsigrok
          ]
        ));

    # ledger-udev-rules

    services.udev.extraRules = concatStringsSep "\n" [
      (optionalString cfg.feitian ''
        KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="096e", TAG+="uaccess"
        SUBSYSTEM=="usb", ATTRS{idVendor}=="096e", TAG+="uaccess"
      '')

      (optionalString cfg.keyboards ''
        KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0660", TAG+="uaccess"
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="1d50", ATTRS{idProduct}=="615e", TAG+="uaccess"
      '')

      # Microcontroller target rules
      (optionalString cfg.microcontrollers ''
        # --- Espressif Ecosystem (ESP32 / ESP8266) ---
        # Native USB / USB-JTAG wrapper for ESP32-S2, ESP32-S3, ESP32-C3, ESP32-C6
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="303a", TAG+="uaccess"
        SUBSYSTEMS=="tty", ATTRS{idVendor}=="303a", TAG+="uaccess"

        # Common USB-to-UART Bridges used on Dev Boards (esptool.py access)
        # Silicon Labs CP210x
        SUBSYSTEMS=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", TAG+="uaccess"
        # Qinheng CH340 / CH341
        SUBSYSTEMS=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="7523", TAG+="uaccess"
        # FTDI FT232 series
        SUBSYSTEMS=="tty", ATTRS{idVendor}=="0403", TAG+="uaccess"

        # --- Raspberry Pi Silicon (RP2040 / RP2350) ---
        # Matches bootloader mode (picotool execution) and runtime CDC-ACM virtual serial ports
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="2e8a", TAG+="uaccess"
        SUBSYSTEMS=="tty", ATTRS{idVendor}=="2e8a", TAG+="uaccess"

        # USBTiny
        ATTR{idVendor}=="1781", ATTR{idProduct}=="0c9f", GROUP="dialout"
      '')
    ];

    services.pcscd.enable = mkIf (cfg.yubikeys || cfg.feitian) true;
  };
}
