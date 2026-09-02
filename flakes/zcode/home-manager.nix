{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.zcode;
  jsonFormat = pkgs.formats.json { };

  mcpServers = lib.optionalAttrs (cfg.enableMcpIntegration && config.programs.mcp.enable) (
    lib.mapAttrs (
      _: server:
      lib.hm.mcp.transformMcpServer {
        inherit server;
        extraTransforms = [ lib.hm.mcp.addType ];
        exclude = [ "serverUrl" ];
      }
    ) config.programs.mcp.servers
  );
in
{
  options.programs.zcode = {
    enable = lib.mkEnableOption "ZCode desktop and Z.AI Coding Tool Helper";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The ZCode desktop package to install.";
    };

    codingHelperPackage = lib.mkOption {
      type = lib.types.package;
      description = "The Z.AI Coding Tool Helper terminal package to install.";
    };

    installCodingHelper = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to install Coding Tool Helper alongside ZCode.";
    };

    enableMcpIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to expose servers declared under programs.mcp.servers through
        ZCode's supported user-level .agents/mcp.json compatibility path.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.mcp.enable = lib.mkDefault cfg.enableMcpIntegration;

    home = {
      packages = [ cfg.package ] ++ lib.optional cfg.installCodingHelper cfg.codingHelperPackage;

      file.".agents/mcp.json" = lib.mkIf (mcpServers != { }) {
        source = jsonFormat.generate "zcode-mcp.json" { inherit mcpServers; };
      };
    };
  };
}
