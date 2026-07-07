{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.preferences.secureBoot;
in
{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  options.preferences.secureBoot.enable = lib.mkEnableOption "Secure Boot support via Lanzaboote";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.sbctl ];

    boot.loader.systemd-boot.enable = lib.mkForce false;

    boot.lanzaboote = {
      enable = true;
      pkiBundle = "/etc/secureboot";
    };
  };
}
