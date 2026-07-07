{ ... }:

{
  programs.nushell = {
    enable = true;

    bomScripts = {
      enable = true;
      scripts = [
        ../../../../../misc/scripts/archive_utils.nu
        ../../../../../misc/scripts/nix.nu
      ];
    };

    configFile.source = ./config.nu;
    extraConfig = ''
      # source ${./prompt.nu}
    '';
  };

  home.shell.enableNushellIntegration = true;
}
