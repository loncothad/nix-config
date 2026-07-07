{ ... }:

{
  imports = [
    ./preferences

    ./user-profiles/by-name/loncothad.nix
    ./user-profiles/default.nix

    ./apparmor-profiles.nix
    ./bluetooth-kill-before-sleep.nix
    ./debloat.nix
    ./external-device-rules.nix
    ./fast-networking.nix
    ./greetd-tuigreet.nix
    ./logs-small.nix
    ./nixos-compat.nix
    ./no-mitigations.nix
    ./pam-limits.nix
    ./profile.nix
    ./tmp-log.nix
    ./virtual-camera.nix
    ./watchdog-timeout.nix
  ];
}
