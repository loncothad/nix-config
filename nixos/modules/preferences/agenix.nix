# agenix-rekey

# age
# rage
# age-plugin-fido2-hmac

{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

with lib;

let
  cfg = config.preferences.agenix;
in
{
  imports = [
    inputs.agenix.nixosModules.default
    inputs.agenix-rekey.nixosModules.default
  ];

  options = {
    preferences.agenix = {
      enable = mkEnableOption "secret management via agenix and agenix-rekey using rage";

      masterKeys = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "List of master public keys used to rekey secrets (e.g., your SSH keys or security keys).";
      };

      extraEncryptionKeys = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Optional backup keys allowed to decrypt rekeyed secrets.";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.rage
      pkgs.age-plugin-fido2-hmac
      inputs.agenix.packages.${pkgs.system}.default
      inputs.agenix-rekey.packages.${pkgs.system}.default
    ];

    age = {
      ageBin = "${pkgs.rage}/bin/rage";

      # identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

      rekey = {
        masterKeys = cfg.masterKeys;
        extraEncryptionKeys = cfg.extraEncryptionKeys;
        storageMode = "local";
        localStorageDir = "${toString inputs.self}/secrets/rekeyed/${config.networking.hostName}";
      };
    };
  };
}
