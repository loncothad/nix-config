{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.preferences.android;
in
{
  options = {
    preferences.android = {
      enable = lib.mkEnableOption "Android tools & USB debug interfaces";
    };
  };

  config = lib.mkIf cfg.enable {
    # systemd 258 and newer supply USB uaccess rules; the ADB NixOS module was removed.
    environment.systemPackages = [ pkgs.android-tools ];
  };
}
