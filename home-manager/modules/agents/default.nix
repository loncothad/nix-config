{
  config,
  lib,
  ...
}:

let
  inherit (lib) mkOption types;
  cfg = config.agents;

  repositoryFiles = builtins.sort (left: right: toString left < toString right) (
    lib.filter (file: builtins.baseNameOf file != "README.md") (
      lib.filesystem.listFilesRecursive cfg.filesDirectory
    )
  );
  repositoryRelativePath = file: lib.removePrefix "${toString cfg.filesDirectory}/" (toString file);

  fileOptions = {
    options = {
      source = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Repository path or store path containing the file.";
      };

      text = mkOption {
        type = types.nullOr types.lines;
        default = null;
        description = "Inline file contents.";
      };

      executable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to make the installed file executable.";
      };
    };
  };

  fileType = types.coercedTo types.path (source: { inherit source; }) (types.submodule fileOptions);

  documentType = types.coercedTo types.path (source: { inherit source; }) (
    types.submodule {
      imports = [ fileOptions ];

      options = {
        enable = lib.mkEnableOption "this agent document" // {
          default = true;
        };

        path = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "prompts/reviewer.md";
          description = ''
            Path below agents.directory. The document's
            schema-specific default is used when this is null.
          '';
        };
      };
    }
  );

  skillType = types.coercedTo types.path (source: { inherit source; }) (
    types.submodule (
      { name, ... }:
      {
        options = {
          enable = lib.mkEnableOption "the ${name} agent skill" // {
            default = true;
          };

          source = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = ''
              Complete skill directory containing SKILL.md and any bundled
              resources. When set, generated skill fields must be left unset.
            '';
          };

          description = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "Review Nix modules for evaluation and composition errors.";
            description = ''
              Discovery description for a generated SKILL.md. It should say
              what the skill does and when an agent should activate it.
            '';
          };

          instructions = mkOption {
            type = types.nullOr fileType;
            default = null;
            example = lib.literalExpression "./skills/nix-review/instructions.md";
            description = "Markdown body of a generated SKILL.md, inline or from a file.";
          };

          license = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "Apache-2.0";
            description = "License name or reference to a bundled license file.";
          };

          compatibility = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "Requires Nix and network access.";
            description = "Environment and product requirements for the skill.";
          };

          metadata = mkOption {
            type = types.attrsOf types.str;
            default = { };
            example = {
              author = "example.org";
              version = "1.0";
            };
            description = "String metadata emitted in the SKILL.md frontmatter.";
          };

          allowedTools = mkOption {
            type = types.listOf types.str;
            default = [ ];
            example = [
              "Bash(gix:*)"
              "Read"
            ];
            description = ''
              Experimental pre-approved tool declarations, emitted as the
              space-separated allowed-tools frontmatter field.
            '';
          };

          files = mkOption {
            type = types.attrsOf fileType;
            default = { };
            example = lib.literalExpression ''
              {
                "references/checklist.md" = ./checklist.md;
                "scripts/check.nu" = {
                  source = ./check.nu;
                  executable = true;
                };
              }
            '';
            description = ''
              Files bundled with a generated skill, relative to its directory.
              Typical subdirectories are scripts, references, and assets.
            '';
          };

          path = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "skills/nix-review";
            description = ''
              Directory below agents.directory. Defaults to
              skills/<attribute-name>.
            '';
          };
        };
      }
    )
  );

  enabledPrompts = lib.filterAttrs (_: prompt: prompt.enable) cfg.prompts;
  enabledSkills = lib.filterAttrs (_: skill: skill.enable) cfg.skills;

  hasExactlyOneContent = file: (file.source == null) != (file.text == null);
  validRelativePath =
    path:
    let
      components = lib.splitString "/" path;
    in
    path != ""
    && !(lib.hasPrefix "/" path)
    && lib.all (component: component != "" && component != "." && component != "..") components;
  fileContents = file: if file.source != null then builtins.readFile file.source else file.text;
  canonicalPath = path: "${cfg.directory}/${path}";

  documentEntries =
    kind: defaultPath: document:
    lib.optionals (document != null && document.enable) (
      let
        path = if document.path == null then defaultPath else document.path;
        value =
          if document.source != null then
            {
              inherit (document) source executable;
            }
          else
            {
              inherit (document) text executable;
            };
      in
      [
        {
          name = canonicalPath path;
          inherit value;
          origin = "agents.${kind}";
        }
      ]
    );

  promptEntries = lib.concatLists (
    lib.mapAttrsToList (
      name: prompt: documentEntries "prompts.${name}" "prompts/${name}.md" prompt
    ) enabledPrompts
  );

  skillFrontmatter =
    name: skill:
    {
      inherit name;
      inherit (skill) description;
    }
    // lib.optionalAttrs (skill.license != null) { inherit (skill) license; }
    // lib.optionalAttrs (skill.compatibility != null) { inherit (skill) compatibility; }
    // lib.optionalAttrs (skill.metadata != { }) { inherit (skill) metadata; }
    // lib.optionalAttrs (skill.allowedTools != [ ]) {
      allowed-tools = lib.concatStringsSep " " skill.allowedTools;
    };

  generatedSkillFile = name: skill: {
    text = ''
      ---
      ${builtins.toJSON (skillFrontmatter name skill)}
      ---

      ${fileContents skill.instructions}
    '';
    executable = false;
  };

  skillEntries = lib.concatLists (
    lib.mapAttrsToList (
      name: skill:
      let
        path = if skill.path == null then "skills/${name}" else skill.path;
        target = canonicalPath path;
      in
      if skill.source != null then
        [
          {
            name = target;
            value.source = skill.source;
            origin = "agents.skills.${name}";
          }
        ]
      else
        [
          {
            name = "${target}/SKILL.md";
            value = generatedSkillFile name skill;
            origin = "agents.skills.${name}";
          }
        ]
        ++ lib.mapAttrsToList (relativePath: file: {
          name = "${target}/${relativePath}";
          value =
            if file.source != null then
              {
                inherit (file) source executable;
              }
            else
              {
                inherit (file) text executable;
              };
          origin = "agents.skills.${name}.files.${relativePath}";
        }) skill.files
    ) enabledSkills
  );

  extraFileEntries = lib.mapAttrsToList (relativePath: file: {
    name = canonicalPath relativePath;
    value =
      if file.source != null then
        {
          inherit (file) source executable;
        }
      else
        {
          inherit (file) text executable;
        };
    origin = "agents.files.${relativePath}";
  }) cfg.files;

  repositoryFileEntries = map (file: {
    name = canonicalPath (repositoryRelativePath file);
    value.source = file;
    origin = "agents.filesDirectory.${repositoryRelativePath file}";
  }) repositoryFiles;

  entries =
    repositoryFileEntries
    ++ documentEntries "globalInstructions" "AGENTS.md" cfg.globalInstructions
    ++ documentEntries "systemPrompt" "SYSTEM.md" cfg.systemPrompt
    ++ promptEntries
    ++ skillEntries
    ++ extraFileEntries;

  entriesByTarget = lib.groupBy (entry: entry.name) entries;
  duplicateTargets = builtins.attrNames (
    lib.filterAttrs (_: targetEntries: builtins.length targetEntries > 1) entriesByTarget
  );
in
{
  options.agents = {
    enable = lib.mkEnableOption "declarative global instructions, prompts, and skills for agents";

    schemaVersion = mkOption {
      type = types.int;
      default = 1;
      readOnly = true;
      description = "Version of the agents option schema for harness integrations.";
    };

    directory = mkOption {
      type = types.str;
      default = "agents";
      example = "agent-config";
      description = ''
        Canonical agent configuration directory relative to XDG_CONFIG_HOME.
        Agent harness modules consume this tree and own their tool-specific
        discovery paths.
      '';
    };

    filesDirectory = mkOption {
      type = types.path;
      default = ./files;
      defaultText = lib.literalExpression "./files";
      description = ''
        Repository directory recursively mirrored into the canonical agent
        tree. Relative paths are preserved, and files named README.md are
        treated as source documentation rather than installed content.
      '';
    };

    paths = {
      root = mkOption {
        type = types.str;
        default = "${config.xdg.configHome}/${cfg.directory}";
        readOnly = true;
        description = "Absolute path to the materialized canonical agent tree.";
      };

      prompts = mkOption {
        type = types.str;
        default = "${cfg.paths.root}/prompts";
        readOnly = true;
        description = "Conventional directory containing named prompts.";
      };

      skills = mkOption {
        type = types.str;
        default = "${cfg.paths.root}/skills";
        readOnly = true;
        description = "Conventional directory containing Agent Skills.";
      };
    };

    globalInstructions = mkOption {
      type = types.nullOr documentType;
      default = null;
      example = lib.literalExpression "./agents/AGENTS.md";
      description = ''
        Global AGENTS.md instructions. A path is shorthand for { source = path; }.
      '';
    };

    systemPrompt = mkOption {
      type = types.nullOr documentType;
      default = null;
      example = lib.literalExpression "./agents/SYSTEM.md";
      description = ''
        Global SYSTEM.md prompt. A path is shorthand for { source = path; }.
      '';
    };

    prompts = mkOption {
      type = types.attrsOf documentType;
      default = { };
      example = lib.literalExpression ''
        {
          reviewer = ./agents/prompts/reviewer.md;
          concise = { text = "Answer concisely."; };
        }
      '';
      description = "Named reusable prompts installed below prompts/ by default.";
    };

    skills = mkOption {
      type = types.attrsOf skillType;
      default = { };
      example = lib.literalExpression ''
        {
          existing-skill = ./agents/skills/existing-skill;
          nix-review = {
            description = "Review Nix code. Use for Nix module and flake reviews.";
            instructions = ./agents/skills/nix-review.md;
          };
        }
      '';
      description = ''
        Agent Skills directories or generated skills. Attribute names are the
        skill names and must follow the Agent Skills naming specification.
      '';
    };

    files = mkOption {
      type = types.attrsOf fileType;
      default = { };
      example = lib.literalExpression ''
        { "context/organization.md" = ./agents/organization.md; }
      '';
      description = "Additional files relative to the canonical agent directory.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = validRelativePath cfg.directory;
        message = "agents.directory must be a safe path relative to XDG_CONFIG_HOME.";
      }
      {
        assertion = duplicateTargets == [ ];
        message = "agents has duplicate installation targets: ${lib.concatStringsSep ", " duplicateTargets}.";
      }
    ]
    ++ lib.optional (cfg.globalInstructions != null && cfg.globalInstructions.enable) {
      assertion = hasExactlyOneContent cfg.globalInstructions;
      message = "agents.globalInstructions must set exactly one of source or text.";
    }
    ++ lib.optional (cfg.systemPrompt != null && cfg.systemPrompt.enable) {
      assertion = hasExactlyOneContent cfg.systemPrompt;
      message = "agents.systemPrompt must set exactly one of source or text.";
    }
    ++ lib.mapAttrsToList (name: prompt: {
      assertion = hasExactlyOneContent prompt;
      message = "agents.prompts.${name} must set exactly one of source or text.";
    }) enabledPrompts
    ++ lib.mapAttrsToList (
      name: skill:
      let
        generated = skill.source == null;
        generatedFieldsUnset =
          skill.description == null
          && skill.instructions == null
          && skill.license == null
          && skill.compatibility == null
          && skill.metadata == { }
          && skill.allowedTools == [ ]
          && skill.files == { };
      in
      {
        assertion =
          builtins.match "[a-z0-9]+(-[a-z0-9]+)*" name != null
          && builtins.stringLength name <= 64
          && (
            if generated then
              skill.description != null
              && skill.description != ""
              && builtins.stringLength skill.description <= 1024
              && skill.instructions != null
              && hasExactlyOneContent skill.instructions
              && (skill.compatibility == null || builtins.stringLength skill.compatibility <= 500)
              && !(skill.files ? "SKILL.md")
            else
              builtins.pathExists (skill.source + "/SKILL.md") && generatedFieldsUnset
          );
        message = ''
          agents.skills.${name} is invalid. Use a valid skill
          name and either a source directory containing SKILL.md or generated
          fields (description plus instructions), but not both.
        '';
      }
    ) enabledSkills
    ++ map (entry: {
      assertion = validRelativePath entry.name;
      message = "${entry.origin} produces an unsafe target path: ${entry.name}.";
    }) entries
    ++ lib.mapAttrsToList (relativePath: file: {
      assertion = validRelativePath relativePath && hasExactlyOneContent file;
      message = "agents.files.${relativePath} must use a safe path and exactly one of source or text.";
    }) cfg.files
    ++ lib.concatLists (
      lib.mapAttrsToList (
        name: skill:
        lib.mapAttrsToList (relativePath: file: {
          assertion =
            validRelativePath relativePath && relativePath != "SKILL.md" && hasExactlyOneContent file;
          message = "agents.skills.${name}.files.${relativePath} is invalid.";
        }) skill.files
      ) enabledSkills
    );

    xdg.configFile = builtins.listToAttrs (
      map (entry: lib.nameValuePair entry.name entry.value) entries
    );

    home.sessionVariables.AGENTS_HOME = cfg.paths.root;
  };
}
