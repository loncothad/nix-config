{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.security.apparmor.appProfiles;
in
{
  options = {
    security.apparmor.appProfiles = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable custom managed AppArmor profiles for specified target applications.";
      };

      brave = {
        enable = mkEnableOption "AppArmor profile for Brave Browser";
        description = ''
          **Allows:**
          - Read/Write to `~/.config/BraveSoftware/` and `~/.cache/BraveSoftware/`.
          - Read/Write to the user's `~/Downloads/` directory.
          - System namespaces (`capability sys_admin, sys_chroot, sys_ptrace`) required for internal Chromium SUID sandboxing.
          - Inbound/outbound TCP/UDP network communication.
          - Session DBus communication for notifications and window management.

          **Restricts:**
          - Blocked from reading any other files inside the user's home directory (e.g., `.ssh`, `.gnupg`, private keys).
          - Blocked from executing binary primitives outside the `/nix/store`.
        '';
      };

      pidgin = {
        enable = mkEnableOption "AppArmor profile for Pidgin 2.x";
        description = ''
          **Allows:**
          - Read/Write access to historical profile layouts (`~/.purple/`) and XDG structures (`~/.config/pidgin/`).
          - System-level audio rendering abstractions and graphical rendering layers.
          - Direct network stream protocols (`inet`, `inet6`).

          **Restricts:**
          - Complete file read isolation from the rest of the user file-space.
          - Subprocess execution isolation; prevents shell execution from message links.
        '';
      };

      telegram = {
        enable = mkEnableOption "AppArmor profile for Telegram Desktop";
        description = ''
          **Allows:**
          - Read/Write to `~/.local/share/TelegramDesktop/` for state persistence.
          - Read/Write to `~/Downloads/` for explicit file saving and media persistence.
          - Full internet protocol sockets.

          **Restricts:**
          - Denies read/write access to arbitrary paths in the home directory or system configurations outside `/nix/store`.
        '';
      };

      _64gram = {
        enable = mkEnableOption "AppArmor profile for 64Gram Telegram Desktop fork";
        description = ''
          **Allows:**
          - Shared states with standard Telegram directories (`~/.local/share/TelegramDesktop/`) alongside unique fork paths (`~/.local/share/64Gram/`).
          - Local write operations targeting `~/Downloads/`.
          - Direct network sockets.

          **Restricts:**
          - Restricts data operations to dedicated state directories to prevent structural access to parallel messenger profiles.
        '';
      };

      zed = {
        enable = mkEnableOption "AppArmor profile for Zed Editor";
        description = ''
          **Allows:**
          - Full recursive Read/Write and locking access to user workspace files under `~/**`.
          - Local configuration structures under `~/.config/zed/` and `~/.local/share/zed/`.
          - **Unconfined Child Execution (`PUx`):** Spawns arbitrary tooling via `/nix/store/**/bin/*` or system paths, letting Rust/Node/Go compiler toolchains and LSPs operate without profile restrictions.

          **Restricts:**
          - Restricts write permissions outside of explicit user home hierarchies and runtime environments.
        '';
      };

      neovim = {
        enable = mkEnableOption "AppArmor profile for Neovim";
        description = ''
          **Allows:**
          - Read/Write access across the user home workspace footprint (`~/**`).
          - Local state/config persistence inside `~/.config/nvim/`.
          - **Unconfined Child Execution (`PUx`):** Executed development binaries, treesitter parsers, and language servers bypass parent profile constraints to ensure build chains work out-of-the-box.

          **Restricts:**
          - Write operations targeting root partitions, arbitrary `/var` directories, or raw hardware devices.
        '';
      };

      helix = {
        enable = mkEnableOption "AppArmor profile for Helix";
        description = ''
          **Allows:**
          - Workspace filesystem access traversing `~/**`.
          - Application-specific configurations via `~/.config/helix/`.
          - **Unconfined Child Execution (`PUx`):** Spawns build pipelines (`cargo`, `go`, etc.) and system language servers dynamically from system binary scopes without hereditary confinement.

          **Restricts:**
          - Write access to systemic partitions outside the scope of home directory workspaces.
        '';
      };

      qimgv = {
        enable = mkEnableOption "AppArmor profile for Qimgv Viewer";
        description = ''
          **Allows:**
          - Pure **Read-Only** validation flags globally inside home boundaries (`~/** r`) to facilitate file previewing.
          - Read/Write configuration parsing to `~/.config/qimgv/`.

          **Restricts:**
          - Absolute block on network interface creation (protects against telemetry or exfiltration via maliciously structured media files).
          - Denies any arbitrary sub-process spawning or binary execution.
        '';
      };

      mpv = {
        enable = mkEnableOption "AppArmor profile for Mpv Media Player";
        description = ''
          **Allows:**
          - **Read-Only** access across `~/**` to load media content.
          - Read/Write operations inside `~/.config/mpv/` for runtime tracking and configurations.
          - Internet stream networking (`inet`, `inet6`) to natively support streaming protocols (e.g., YouTube playback integration).

          **Restricts:**
          - Complete lack of filesystem write execution permissions across general system boundaries.
          - Denies capability escalations and child executions.
        '';
      };

      ghostty = {
        enable = mkEnableOption "AppArmor profile for Ghostty Terminal Emulator";
        description = ''
          **Allows:**
          - Pseudo-terminal access patterns via interactive device definitions (`/dev/pts/*`).
          - Read/Write profile configuration access via `~/.config/ghostty/`.
          - **Unconfined Child Execution (`PUx`):** Interfacing shells (`zsh`, `bash`, `fish`) are decoupled from AppArmor confinement upon invocation, ensuring user shell sessions run unrestricted.

          **Restricts:**
          - Restricts the core terminal multiplexer wrapper from modifying root system configurations directly before execution loops begin.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    security.apparmor.enable = true;

    security.apparmor.policies = mkMerge [
      (mkIf cfg.brave.enable {
        brave.profile = ''
          #include <abstractions/base>
          #include <abstractions/graphical>
          #include <abstractions/audio>
          #include <abstractions/cups-client>
          #include <abstractions/nameservice>
          #include <abstractions/user-download>
          #include <abstractions/fonts>

          profile brave ${pkgs.brave}/bin/brave flags=(attach_disconnected) {
            #include <abstractions/base>
            #include <abstractions/graphical>
            #include <abstractions/audio>
            #include <abstractions/fonts>
            
            /nix/store/** r,
            /nix/store/**/bin/* ix,
            /run/current-system/sw/share/** r,

            owner @{HOME}/.config/BraveSoftware/ rw,
            owner @{HOME}/.config/BraveSoftware/** rwk,
            owner @{HOME}/.cache/BraveSoftware/ rw,
            owner @{HOME}/.cache/BraveSoftware/** rwk,
            owner @{HOME}/Downloads/ rw,
            owner @{HOME}/Downloads/** rw,

            capability sys_admin,
            capability sys_chroot,
            capability sys_ptrace,

            dbus send bus=session,
            dbus receive bus=session,

            network inet stream,
            network inet6 stream,
          }
        '';
      })

      (mkIf cfg.pidgin.enable {
        pidgin.profile = ''
          #include <abstractions/base>
          #include <abstractions/graphical>
          #include <abstractions/audio>
          #include <abstractions/nameservice>

          profile pidgin ${pkgs.pidgin}/bin/pidgin flags=(attach_disconnected) {
            #include <abstractions/base>
            #include <abstractions/graphical>
            #include <abstractions/audio>
            #include <abstractions/nameservice>

            /nix/store/** r,
            owner @{HOME}/.purple/ rw,
            owner @{HOME}/.purple/** rwk,
            owner @{HOME}/.config/pidgin/ rw,
            owner @{HOME}/.config/pidgin/** rw,

            network inet stream,
            network inet6 stream,
          }
        '';
      })

      (mkIf cfg.telegram.enable {
        telegram.profile = ''
          #include <abstractions/base>
          #include <abstractions/graphical>
          #include <abstractions/audio>
          #include <abstractions/nameservice>

          profile telegram ${pkgs.telegram-desktop}/bin/telegram-desktop flags=(attach_disconnected) {
            #include <abstractions/base>
            #include <abstractions/graphical>
            #include <abstractions/audio>
            #include <abstractions/nameservice>

            /nix/store/** r,
            owner @{HOME}/.local/share/TelegramDesktop/ rw,
            owner @{HOME}/.local/share/TelegramDesktop/** rwk,
            owner @{HOME}/Downloads/ rw,
            owner @{HOME}/Downloads/** rw,

            network inet stream,
            network inet6 stream,
          }
        '';
      })

      (mkIf cfg._64gram.enable {
        _64gram.profile = ''
          #include <abstractions/base>
          #include <abstractions/graphical>
          #include <abstractions/audio>
          #include <abstractions/nameservice>

          profile _64gram ${(lib.getExe pkgs._64gram)} flags=(attach_disconnected) {
            #include <abstractions/base>
            #include <abstractions/graphical>
            #include <abstractions/audio>
            #include <abstractions/nameservice>

            /nix/store/** r,
            owner @{HOME}/.local/share/TelegramDesktop/ rw,
            owner @{HOME}/.local/share/TelegramDesktop/** rwk,
            owner @{HOME}/.local/share/64Gram/ rw,
            owner @{HOME}/.local/share/64Gram/** rwk,
            owner @{HOME}/Downloads/ rw,
            owner @{HOME}/Downloads/** rw,

            network inet stream,
            network inet6 stream,
          }
        '';
      })

      (mkIf cfg.zed.enable {
        zed.profile = ''
          #include <abstractions/base>
          #include <abstractions/graphical>
          #include <abstractions/nameservice>

          profile zed ${pkgs.zed-editor}/bin/zed flags=(attach_disconnected) {
            #include <abstractions/base>
            #include <abstractions/graphical>
            #include <abstractions/nameservice>

            /nix/store/** r,
            owner @{HOME}/** rwl,
            owner @{HOME}/.config/zed/ rw,
            owner @{HOME}/.config/zed/** rwk,
            owner @{HOME}/.local/share/zed/ rw,
            owner @{HOME}/.local/share/zed/** rwk,

            /nix/store/**/bin/* PUx,
            /run/current-system/sw/bin/* PUx,
          }
        '';
      })

      (mkIf cfg.neovim.enable {
        neovim.profile = ''
          #include <abstractions/base>

          profile neovim ${pkgs.neovim}/bin/nvim flags=(attach_disconnected) {
            #include <abstractions/base>

            /nix/store/** r,
            owner @{HOME}/** rwl,
            owner @{HOME}/.config/nvim/ rw,
            owner @{HOME}/.config/nvim/** rwk,

            /nix/store/**/bin/* PUx,
            /run/current-system/sw/bin/* PUx,
          }
        '';
      })

      (mkIf cfg.helix.enable {
        helix.profile = ''
          #include <abstractions/base>

          profile helix ${pkgs.helix}/bin/hx flags=(attach_disconnected) {
            #include <abstractions/base>

            /nix/store/** r,
            owner @{HOME}/** rwl,
            owner @{HOME}/.config/helix/ rw,
            owner @{HOME}/.config/helix/** rwk,

            /nix/store/**/bin/* PUx,
            /run/current-system/sw/bin/* PUx,
          }
        '';
      })

      (mkIf cfg.qimgv.enable {
        qimgv.profile = ''
          #include <abstractions/base>
          #include <abstractions/graphical>

          profile qimgv ${pkgs.qimgv}/bin/qimgv flags=(attach_disconnected) {
            #include <abstractions/base>
            #include <abstractions/graphical>

            /nix/store/** r,
            owner @{HOME}/** r,
            owner @{HOME}/.config/qimgv/ rw,
            owner @{HOME}/.config/qimgv/** rwk,
          }
        '';
      })

      (mkIf cfg.mpv.enable {
        mpv.profile = ''
          #include <abstractions/base>
          #include <abstractions/graphical>
          #include <abstractions/audio>

          profile mpv ${pkgs.mpv}/bin/mpv flags=(attach_disconnected) {
            #include <abstractions/base>
            #include <abstractions/graphical>
            #include <abstractions/audio>

            /nix/store/** r,
            owner @{HOME}/** r,
            owner @{HOME}/.config/mpv/ rw,
            owner @{HOME}/.config/mpv/** rwk,

            network inet stream,
            network inet6 stream,
          }
        '';
      })

      (mkIf cfg.ghostty.enable {
        ghostty.profile = ''
          #include <abstractions/base>
          #include <abstractions/graphical>

          profile ghostty ${pkgs.ghostty}/bin/ghostty flags=(attach_disconnected) {
            #include <abstractions/base>
            #include <abstractions/graphical>

            /dev/pts/* rw,
            /nix/store/** r,
            owner @{HOME}/.config/ghostty/ rw,
            owner @{HOME}/.config/ghostty/** rwk,

            /run/current-system/sw/bin/* PUx,
            /nix/store/**/bin/* PUx,
          }
        '';
      })
    ];
  };
}
