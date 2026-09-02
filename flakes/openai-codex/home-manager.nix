{
  config,
  lib,
  ...
}:

let
  cfg = config.programs.openai-codex;
in
{
  options.programs.openai-codex = {
    enable = lib.mkEnableOption "OpenAI Codex CLI and ChatGPT desktop client";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The Codex CLI package to install.";
    };

    desktopPackage = lib.mkOption {
      type = lib.types.package;
      description = "The ChatGPT desktop package to install.";
    };

    installDesktop = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to install the ChatGPT desktop client alongside Codex.";
    };

    enableMcpIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to expose servers declared under programs.mcp.servers to
        Codex through Home Manager's native Codex integration.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs = {
      codex = {
        enable = true;
        package = cfg.package;
        enableMcpIntegration = cfg.enableMcpIntegration;
      };

      mcp.enable = lib.mkDefault cfg.enableMcpIntegration;
    };

    home.packages = lib.optional cfg.installDesktop cfg.desktopPackage;
  };
}
