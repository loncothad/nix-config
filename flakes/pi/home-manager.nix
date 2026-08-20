{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.programs.pi;
  jsonFormat = pkgs.formats.json { };

  fileType = types.submodule {
    options = {
      source = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path copied into the pi config directory.";
      };

      text = mkOption {
        type = types.nullOr types.lines;
        default = null;
        description = "Literal file contents written into the pi config directory.";
      };
    };
  };

  coercedFileType = types.coercedTo types.path (source: {
    inherit source;
    text = null;
  }) fileType;

  resourceFilesType =
    kind:
    mkOption {
      type = types.attrsOf coercedFileType;
      default = { };
      example = literalExpression ''
        {
          "example.ts" = ./extensions/example.ts;
          "inline.ts".text = '''
            export default function (pi) {}
          ''';
        }
      '';
      description = ''
        Files installed under {file}`${cfg.configDir}/${kind}/`.
        Attribute names may include slashes (e.g. {file}`my-skill/SKILL.md`).
        A path value is copied as-is; use `.text` for inline contents.
      '';
    };

  homeDir = config.home.homeDirectory;

  relConfigDir =
    if hasPrefix "${homeDir}/" cfg.configDir then
      removePrefix "${homeDir}/" cfg.configDir
    else
      ".pi/agent";

  toHomeFile =
    name: file:
    nameValuePair name (
      if file.text != null then
        { text = file.text; }
      else
        {
          source = file.source;
        }
    );

  resourceHomeFiles =
    subdir: files:
    mapAttrs' (name: file: toHomeFile "${relConfigDir}/${subdir}/${name}" file) files;

  fileAssertions =
    prefix: files:
    mapAttrsToList (
      name: file:
      {
        assertion = (file.source != null) != (file.text != null);
        message = "programs.pi.${prefix}.${name} must set exactly one of source or text.";
      }
    ) files;

  toPackageEntry = p: if builtins.isString p then p else "${p}";

  effectiveSettings =
    let
      declared = map toPackageEntry cfg.packages;
      fromSettings = cfg.settings.packages or [ ];
    in
    if declared == [ ] then
      cfg.settings
    else
      cfg.settings
      // {
        packages = declared ++ fromSettings;
      };
in
{
  options.programs.pi = {
    enable = mkEnableOption "pi, a terminal coding agent";

    package = mkPackageOption pkgs "pi-coding-agent" {
      nullable = true;
    };

    packages = mkOption {
      type = types.listOf (types.either types.str types.package);
      default = [ ];
      example = literalExpression ''
        with pkgs.piExtensions; [
          pi-web-access
          pi-goal-x
          "npm:some-unpinned-package"
        ]
      '';
      description = ''
        Pi packages loaded at startup. Derivations (from
        {option}`pkgs.piExtensions` / {command}`buildPiNpmPackage`) become
        local paths. Strings are passed through as `npm:` / `git:` specs.
        Merged in front of {option}`programs.pi.settings.packages`.
      '';
    };

    configDir = mkOption {
      type = types.str;
      default = "${homeDir}/.pi/agent";
      defaultText = literalExpression ''"''${config.home.homeDirectory}/.pi/agent"'';
      description = ''
        Pi config directory (`PI_CODING_AGENT_DIR`). Must live under the home
        directory. Defaults to {file}`~/.pi/agent`.
      '';
    };

    settings = mkOption {
      type = jsonFormat.type;
      default = { };
      example = literalExpression ''
        {
          defaultProvider = "anthropic";
          defaultModel = "claude-sonnet-4-20250514";
          defaultThinkingLevel = "medium";
          theme = "dark";
          quietStartup = true;
          defaultProjectTrust = "ask";
          enabledModels = [ "claude-*" "gpt-4o" ];
          packages = [
            "npm:pi-web-access"
            {
              source = "npm:@org/pkg";
              skills = [ "one" ];
              extensions = [ ];
            }
          ];
          compaction = {
            enabled = true;
            reserveTokens = 16384;
            keepRecentTokens = 20000;
          };
          retry = {
            enabled = true;
            maxRetries = 3;
          };
        }
      '';
      description = ''
        Global settings written to {file}`${cfg.configDir}/settings.json`.

        Common keys (see https://pi.dev docs/settings.md):

        - Model: `defaultProvider`, `defaultModel`, `defaultThinkingLevel`
          (`off`/`minimal`/`low`/`medium`/`high`/`xhigh`/`max`),
          `hideThinkingBlock`, `thinkingBudgets`, `enabledModels`
        - UI: `theme`, `externalEditor`, `quietStartup`, `defaultProjectTrust`
          (`ask`/`always`/`never`), `tuiMode`, `doubleEscapeAction`
        - Compaction / retry / transport: `compaction`, `branchSummary`,
          `retry`, `steeringMode`, `followUpMode`, `transport`
        - Shell: `shellPath`, `shellCommandPrefix`, `npmCommand`
        - Resources: `packages`, `extensions`, `skills`, `prompts`, `themes`,
          `enableSkillCommands`, `defaultTools`
        - Other: `sessionDir`, `httpProxy`, `warnings`, `terminal`, `images`,
          `markdown`

        Runtime writes from `/settings` or `/model` fail if this file is a
        store symlink. Leave this empty to keep a mutable settings file.
      '';
    };

    models = mkOption {
      type = jsonFormat.type;
      default = { };
      example = literalExpression ''
        {
          providers = {
            ollama = {
              baseUrl = "http://localhost:11434/v1";
              api = "openai-completions";
              apiKey = "ollama";
              models = [ { id = "llama3.1:8b"; } ];
            };
          };
        }
      '';
      description = ''
        Custom providers and models written to
        {file}`${cfg.configDir}/models.json`. See docs/models.md.
        Leave empty to skip managing the file.
      '';
    };

    keybindings = mkOption {
      type = types.attrsOf (types.either types.str (types.listOf types.str));
      default = { };
      example = literalExpression ''
        {
          "tui.editor.historyPrevious" = "ctrl+p";
          "tui.editor.historyNext" = "ctrl+n";
          "tui.editor.deleteWordBackward" = [ "ctrl+w" "alt+backspace" ];
        }
      '';
      description = ''
        Custom keybindings written to
        {file}`${cfg.configDir}/keybindings.json`.
        Values are a single key or a list of keys. See docs/keybindings.md.
      '';
    };

    agentsMd = mkOption {
      type = types.nullOr types.lines;
      default = null;
      example = ''
        - Prefer small, reviewable diffs.
        - Run project checks after code changes.
      '';
      description = ''
        Global agent instructions written to
        {file}`${cfg.configDir}/AGENTS.md`.
      '';
    };

    extensions = resourceFilesType "extensions";
    skills = resourceFilesType "skills";
    prompts = resourceFilesType "prompts";
    themes = resourceFilesType "themes";

    extraFiles = mkOption {
      type = types.attrsOf coercedFileType;
      default = { };
      example = literalExpression ''
        {
          "notes.md".text = "project-local notes";
        }
      '';
      description = ''
        Extra files installed directly under {file}`${cfg.configDir}/`.
        Attribute names are relative paths. Do not manage `auth.json`,
        `trust.json`, or `sessions/` here.
      '';
    };

    skipVersionCheck = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        When non-null, sets `PI_SKIP_VERSION_CHECK`. The nixpkgs package
        already defaults this to enabled.
      '';
    };

    telemetry = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        When non-null, sets `PI_TELEMETRY` (`1`/`0`). Overrides install
        telemetry and provider attribution headers.
      '';
    };

    offline = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Sets `PI_OFFLINE=1`, disabling startup network operations (update
        checks, package updates, install telemetry).
      '';
    };

    sessionVariables = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = {
        PI_CACHE_RETENTION = "long";
      };
      description = ''
        Extra environment variables exported for pi. Provider API keys can
        live here, but prefer a secret manager or {file}`auth.json`
        created by `/login`.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = flatten [
      (fileAssertions "extensions" cfg.extensions)
      (fileAssertions "skills" cfg.skills)
      (fileAssertions "prompts" cfg.prompts)
      (fileAssertions "themes" cfg.themes)
      (fileAssertions "extraFiles" cfg.extraFiles)
    ];

    home.packages = mkIf (cfg.package != null) [ cfg.package ];

    home.sessionVariables = mkMerge [
      (mkIf (cfg.configDir != "${homeDir}/.pi/agent") {
        PI_CODING_AGENT_DIR = cfg.configDir;
      })
      (mkIf (cfg.skipVersionCheck != null) {
        PI_SKIP_VERSION_CHECK = if cfg.skipVersionCheck then "1" else "0";
      })
      (mkIf (cfg.telemetry != null) {
        PI_TELEMETRY = if cfg.telemetry then "1" else "0";
      })
      (mkIf cfg.offline {
        PI_OFFLINE = "1";
      })
      cfg.sessionVariables
    ];

    home.file = mkMerge [
      (mkIf (effectiveSettings != { }) {
        "${relConfigDir}/settings.json".source =
          jsonFormat.generate "pi-settings.json" effectiveSettings;
      })
      (mkIf (cfg.models != { }) {
        "${relConfigDir}/models.json".source = jsonFormat.generate "pi-models.json" cfg.models;
      })
      (mkIf (cfg.keybindings != { }) {
        "${relConfigDir}/keybindings.json".source =
          jsonFormat.generate "pi-keybindings.json" cfg.keybindings;
      })
      (mkIf (cfg.agentsMd != null) {
        "${relConfigDir}/AGENTS.md".text = cfg.agentsMd;
      })
      (resourceHomeFiles "extensions" cfg.extensions)
      (resourceHomeFiles "skills" cfg.skills)
      (resourceHomeFiles "prompts" cfg.prompts)
      (resourceHomeFiles "themes" cfg.themes)
      (mapAttrs' (name: file: toHomeFile "${relConfigDir}/${name}" file) cfg.extraFiles)
    ];
  };
}
