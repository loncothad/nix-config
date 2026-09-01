{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.autolith;

  uniqueExtensions = lib.unique cfg.extensions;
  extensionsByPath = lib.groupBy toString cfg.extensions;
  duplicateExtensionPaths = builtins.attrNames (
    lib.filterAttrs (_: extensions: builtins.length extensions > 1) extensionsByPath
  );

  extensionLoader = extension: ''
    (load #p${builtins.toJSON extension} :verbose nil :print nil)
  '';

  initText = lib.concatStringsSep "\n\n" (
    lib.filter (part: part != "") [
      "(in-package #:autolith)"
      cfg.extraConfig
      (lib.concatMapStrings extensionLoader uniqueExtensions)
    ]
  );

  managedConfigFiles = lib.mapAttrs' (
    relativePath: source: lib.nameValuePair "autolith/${relativePath}" { inherit source; }
  ) cfg.configFiles;
in
{
  options.programs.autolith = {
    enable = lib.mkEnableOption "Autolith, a live Common Lisp agent (documentation: https://github.com/lambda-symbolics/autolith#readme)";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.fromFlakes.autolith.autolith;
      defaultText = lib.literalExpression "pkgs.fromFlakes.autolith.autolith";
      description = "The Autolith package to install.";
    };

    model = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "openrouter/anthropic/claude-sonnet-4";
      description = "Default provider and model, exported as AUTOLITH_MODEL.";
    };

    reasoningEffort = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "medium";
      description = "Default reasoning effort, exported as AUTOLITH_REASONING_EFFORT.";
    };

    environmentVariables = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional non-secret environment variables for Autolith.";
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      example = lib.literalExpression "builtins.readFile ./config/init.lisp";
      description = ''
        Common Lisp appended to Autolith's generated global init.lisp before
        extension load forms.
      '';
    };

    extensions = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      example = lib.literalExpression "[ ./extensions/my-command.lisp ]";
      description = ''
        Common Lisp extension files loaded in order from Autolith's global
        init.lisp. Extensions execute in the AUTOLITH package with the user's
        full privileges.
      '';
    };

    configFiles = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      example = lib.literalExpression ''
        {
          "mcp.sexp" = ./config/mcp.sexp;
          "agents/reviewer.sexp" = ./config/agents/reviewer.sexp;
        }
      '';
      description = ''
        Additional Autolith configuration files keyed by their path relative
        to the Autolith configuration directory.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    warnings = map (
      path: "programs.autolith.extensions: ignored duplicate extension \"${path}\"."
    ) duplicateExtensionPaths;

    home.packages = [ cfg.package ];

    home.sessionVariables =
      cfg.environmentVariables
      // lib.optionalAttrs (cfg.model != null) {
        AUTOLITH_MODEL = cfg.model;
      }
      // lib.optionalAttrs (cfg.reasoningEffort != null) {
        AUTOLITH_REASONING_EFFORT = cfg.reasoningEffort;
      };

    xdg.configFile =
      managedConfigFiles
      // lib.optionalAttrs (cfg.extraConfig != "" || uniqueExtensions != [ ]) {
        "autolith/init.lisp".text = initText + "\n";
      };
  };
}
