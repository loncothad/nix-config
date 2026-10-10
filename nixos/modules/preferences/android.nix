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
    environment.systemPackages = [ pkgs.android-tools ];
  };
}
