{ inputs, pkgs }:
let
  inherit (pkgs) lib;
  hosts = lib.mapAttrs (
    _: host:
    let
      c = host.config;
      h = c.home-manager.users.loncothad;
      homeFile = name: h.xdg.configFile.${name}.source;
      program = name: file: {
        exe = lib.getExe h.programs.${name}.package;
        config = homeFile file;
      };
    in
    {
      niri = {
        exe = lib.getExe host.pkgs.niri;
        config = homeFile "niri/config.kdl";
        include = homeFile "niri/host-settings.kdl";
      };
      ghostty = program "ghostty" "ghostty/config";
      fuzzel = program "fuzzel" "fuzzel/fuzzel.ini";
      zellij = program "zellij" "zellij/config.kdl";
      hyprlock = program "hyprlock" "hypr/hyprlock.conf";
      mpv = program "mpv" "mpv/mpv.conf";
      schemas = {
        bottom = {
          config = h.programs.bottom.settings;
          schema = "${host.pkgs.bottom.src}/schema/v${host.pkgs.bottom.version}/bottom.json";
        };
        jujutsu = {
          config = h.programs.jujutsu.settings;
          schema = "${host.pkgs.jujutsu.src}/cli/src/config-schema.json";
        };
        lazygit = {
          config = h.programs.lazygit.settings;
          schema = "${host.pkgs.lazygit.src}/schema/config.json";
        };
      };
      jujutsu = {
        exe = lib.getExe h.programs.jujutsu.package;
        config = h.home.file."${h.xdg.configHome}/jj/config.toml".source;
      };
      git = program "git" "git/config";
      tealdeer = {
        exe = lib.getExe h.programs.tealdeer.package;
        config = h.home.file."${h.xdg.configHome}/tealdeer/config.toml".source;
      };
      nushell = {
        exe = lib.getExe h.programs.nushell.package;
        config = h.programs.nushell.configFile.source;
      };
      ashell = {
        exe = lib.getExe h.programs.ashell.package;
        # Send parser diagnostics to stderr in the isolated test process.
        config = (pkgs.formats.toml { }).generate "ashell-audit.toml" (
          h.programs.ashell.settings
          // {
            logging = {
              level = "debug";
              target = "stderr";
            };
          }
        );
      };
      scx = {
        packages = c.services.scx-loader.schedsPackages;
        settings = c.services.scx-loader.config;
      };
      tmpfiles = {
        rules = pkgs.writeText "tmpfiles-audit.conf" (lib.concatLines c.systemd.tmpfiles.rules);
        users = lib.mapAttrs (_: u: { inherit (u) uid group; }) c.users.users;
        groups = lib.mapAttrs (_: g: g.gid) c.users.groups;
      };
      gtk2 = {
        library = "${host.pkgs.gtk2}/lib/libgtk-x11-2.0.so.0";
        config = h.home.file.${h.gtk.gtk2.configLocation}.source;
      };
    }
    // lib.optionalAttrs c.hardware.bluetooth.enable {
      bluez = {
        source = host.pkgs.bluez.src;
        config = c.environment.etc."bluetooth/main.conf".source;
      };
    }
    // lib.optionalAttrs c.security.rtkit.enable {
      rtkit = {
        exe = "${host.pkgs.rtkit}/libexec/rtkit-daemon";
        inherit (c.security.rtkit) args;
      };
    }
    // lib.optionalAttrs (c.services.pipewire.enable && c.services.pipewire.wireplumber.enable) {
      wireplumber = {
        source = host.pkgs.pipewire.src;
        schema = "${host.pkgs.wireplumber}/share/wireplumber/wireplumber.conf";
        config = c.services.pipewire.wireplumber.extraConfig;
      };
    }
    // lib.optionalAttrs c.services.greetd.tuigreet.enable {
      tuigreet = {
        exe = lib.getExe c.services.greetd.tuigreet.package;
        config = c.environment.etc."tuigreet/config.toml".source;
      };
    }
  ) inputs.self.nixosConfigurations;
  manifest = pkgs.writeText "configuration-audit.json" (
    builtins.toJSON {
      inherit hosts;
      tmpfiles = "${pkgs.systemd}/bin/systemd-tmpfiles";
    }
  );
in
pkgs.runCommand "configuration-checks"
  { nativeBuildInputs = [ (pkgs.python3.withPackages (ps: [ ps.jsonschema ])) ]; }
  ''
    mkdir -p $out
    python3 ${./configuration.py} ${manifest} $out
  ''
