{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.preferences.home-manager;
in
{
  options = {
    preferences.home-manager = {
      enable = mkEnableOption "home-manager setup";
    };
  };

  config = mkIf cfg.enable {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
  };
}
