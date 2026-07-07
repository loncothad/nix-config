{ inputs, pkgs, ... }:

{
  imports = [
    ./hardware-setup.nix
  ];

  networking.hostName = "kepler";
  networking.networkmanager.enable = true;

  host.profile = {
    enable = true;
    purpose = "desktop";
    platform = "nixos";
    hardware = {
      cpuArchitecture = "v3"; # Core Ultra X9 388H (no AVX512)
      schedExtMode = "auto";
    };
  };

  preferences.agenix = {
    # enable = true;
    masterKeys = [

    ];
  };

  security.sudo.enable = false;
  security.sudo-rs = {
    enable = true;
    wheelNeedsPassword = false;
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.systemd.enable = true;

  systemd.network.wait-online.anyInterface = true;

  programs.niri = {
    enable = true;
    useNautilus = false;
  };

  services.greetd.tuigreet = {
    enable = true;
    package = inputs.tuigreet.packages.${pkgs.system}.default;

    settings = {
      display = {
        show_time = true;
        greeting = "System Lock: Kepler";
        align_greeting = "center";
        issue = false;
      };

      layout = {
        width = 80;
        window_padding = 4;
        container_padding = 2;
        prompt_padding = 1;

        widgets = {
          time_position = "top";
          status_position = "bottom";
        };
      };

      remember = {
        username = true;
        session = true;
        user_session = true;
      };

      user_menu = {
        enabled = true;
        min_uid = 1000;
        max_uid = 60000;
      };

      secret = {
        mode = "characters";
        characters = "●";
      };

      outputs = [
        {
          connector = "eDP-1";
          primary = true;
          enabled = true;
        }
      ];

      background = {
        kind = "doom";
        fps = 30;

        doom = {
          height = 6;
          spread = 2;
          top_color = "#f38ba8";
          middle_color = "#fab387";
          bottom_color = "#11111b";
        };
      };

      theme = {
        border = "blue";
        text = "white";
        time = "yellow";
        container = "black";
        title = "magenta";
        greet = "cyan";
        prompt = "green";
        input = "bright-white";
        action = "blue";
        button = "bright-red";
      };
    };
  };

  preferences.core = {
    enable = true;
    timeZone = "Europe/Moscow";
    defaultLocale = "en_US.UTF-8";
  };

  preferences.fonts.enable = true;

  preferences.audio = {
    enable = true;
    bluetooth.enable = true;
  };
  services.bluetooth-kill-before-sleep.enable = true;

  preferences.networking = {
    sysctl = {
      enableBBR = true;
      enableHardening = true;
    };
    dns = {
      enable = true;
      mode = "dot";
    };
    time = {
      enable = true;
      mode = "client";
    };
    firewall = {
      enable = true;
      allowLocalDiscovery = true;
    };
  };
  networking.optimizations.enable = true;

  preferences.secureBoot.enable = false; # Toggle true once setup using sbctl keys is initialized

  hardware = {
    brillo.enable = true;
    i2c.enable = true;
    extraDeviceRules = {
      enable = true;
      yubikeys = true;
      feitian = true;
      keyboards = true;
      microcontrollers = true;
    };
  };

  security.apparmor.profiles = {
    enable = true;
    brave.enable = true;
    telegram.enable = true;
    zed.enable = true;
    neovim.enable = true;
    helix.enable = true;
    qimgv.enable = true;
    mpv.enable = true;
    ghostty.enable = true;
  };

  nixos-compatibility = {
    enable = true;
    enableGUI = true;
  };

  security.pam.enableUnlimited = true;
  systemd.small-logs.enable = true;

  preferences.home-manager.enable = true;
  users.profiles.loncothad = {
    enable = true;
    hashedPasswordFile = null; # Manage via agenix or interactive setup
  };
}
