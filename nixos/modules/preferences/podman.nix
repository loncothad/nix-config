{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.preferences.podman;
in
{
  options = {
    preferences.podman = {
      enable = lib.mkEnableOption "rootless Podman container engine";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };
    environment.systemPackages = [ pkgs.podman-compose ];
  };
}
