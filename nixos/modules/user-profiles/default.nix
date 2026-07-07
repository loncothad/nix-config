{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.users.profiles;
  userOpts = { name, ... }: {
    options = {
      enable = mkEnableOption "the application of this system user profile";
      description = mkOption {
        type = types.str;
        default = name;
      };
      extraGroups = mkOption {
        type = types.listOf types.str;
        default = [
          "wheel"
          "video"
          "audio"
          "networkmanager"
        ];
      };
      shell = mkOption {
        type = types.shell;
        default = pkgs.bashInteractive;
      };
      hashedPasswordFile = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      homeManagerConfig = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to the user's home-manager specification.";
      };
    };
  };
in
{
  options.users.profiles = mkOption {
    type = types.attrsOf (types.submodule userOpts);
    default = { };
    description = "Declarative multi-user profiles mapped to home-manager.";
  };

  config = {
    users.mutableUsers = mkDefault false;

    users.users = mapAttrs (name: u: {
      isNormalUser = true;
      description = u.description;
      extraGroups = u.extraGroups;
      shell = u.shell;
      hashedPasswordFile = u.hashedPasswordFile;
    }) (filterAttrs (name: u: u.enable) cfg);

    home-manager.users = mapAttrs (name: u: u.homeManagerConfig) (
      filterAttrs (name: u: u.enable && u.homeManagerConfig != null) cfg
    );
  };
}
