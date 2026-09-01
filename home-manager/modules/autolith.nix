{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.autolith;

  extensionLoader = extension: ''
    (load #p${builtins.toJSON extension} :verbose nil :print nil)
  '';
in
{
  options.programs.autolith = {
    enable = lib.mkEnableOption "Autolith, a live Common Lisp agent";

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
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    home.sessionVariables =
      cfg.environmentVariables
      // lib.optionalAttrs (cfg.model != null) {
        AUTOLITH_MODEL = cfg.model;
      }
      // lib.optionalAttrs (cfg.reasoningEffort != null) {
        AUTOLITH_REASONING_EFFORT = cfg.reasoningEffort;
      };

    xdg.configFile."autolith/init.lisp" = lib.mkIf (cfg.extensions != [ ]) {
      text = ''
        (in-package #:autolith)

        ${lib.concatMapStrings extensionLoader cfg.extensions}
      '';
    };
  };
}
