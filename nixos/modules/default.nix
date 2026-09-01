{ ... }:

{
  imports = [
    ./preferences
    ./auto-update.nix
    ./checkmate.nix
    ./containers.nix
    ./convertx.nix
    ./homarr.nix
    ./omni-tools.nix
    ./oxicloud.nix
    ./rauthy.nix
    ./rybbit.nix
    ./usesend.nix

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
