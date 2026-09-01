# Agent configuration module

`homeModules.agents` defines a vendor-neutral, global source of agent
instructions, prompts, skills, and supporting files. It materializes a stable
tree under `$XDG_CONFIG_HOME/agents` by default:

```text
agents/
├── AGENTS.md
├── SYSTEM.md
├── prompts/
│   └── <name>.md
├── skills/
│   └── <name>/
│       ├── SKILL.md
│       ├── scripts/
│       ├── references/
│       └── assets/
└── <additional files>
```

This module does not install an agent harness or write vendor-specific paths.
A harness integration can inspect `config.agents`, use
`config.agents.paths.root`, `config.agents.paths.prompts`, or
`config.agents.paths.skills`, and expose the relevant content in its own
discovery location. `agents.schemaVersion` versions that integration contract.

## Documents and prompts

`globalInstructions`, `systemPrompt`, and each member of `prompts` use the same
file schema:

| Option | Type | Meaning |
| --- | --- | --- |
| `enable` | Boolean | Include this document; defaults to `true`. |
| `source` | Path or null | A repository or store file. |
| `text` | Lines or null | Inline content. |
| `path` | String or null | Override its path within the canonical tree. |
| `executable` | Boolean | Preserve an executable use case; defaults to `false`. |

Exactly one of `source` and `text` is required. A bare Nix path is shorthand
for `{ source = path; }`, so repository-owned files remain concise:

```nix
agents = {
  enable = true;
  globalInstructions = ./agents/AGENTS.md;
  systemPrompt = ./agents/SYSTEM.md;

  prompts = {
    reviewer = ./agents/prompts/reviewer.md;
    concise.text = "Prefer a concise answer.";
  };
};
```

By default, the two global documents become `AGENTS.md` and `SYSTEM.md`, while
named prompts become `prompts/<name>.md`. `path` exists for deliberately
different layouts without weakening the default contract.

## Skills

`skills` is keyed by the skill name. Names are validated against the Agent
Skills rules: lowercase letters, digits, and single hyphens, with a maximum of
64 characters. A complete repository directory is the preferred shorthand:

```nix
agents.skills.nix-review = ./agents/skills/nix-review;
```

The directory must contain `SKILL.md`; all of its `scripts/`, `references/`,
`assets/`, and other resources travel with it. This is the best form for a
portable skill authored directly according to the
[Agent Skills specification](https://agentskills.io/specification).

The module can also generate the skill entry point while keeping its body and
resources in repository files:

```nix
agents.skills.nix-review = {
  description = "Review Nix modules and flakes. Use for Nix code reviews.";
  instructions = ./agents/skills/nix-review/instructions.md;
  license = "MIT";
  compatibility = "Requires Nix with flakes enabled.";
  metadata = {
    author = "example.org";
    version = "1.0";
  };
  allowedTools = [
    "Bash(nix:*)"
    "Read"
  ];
  files = {
    "references/checklist.md" = ./agents/skills/nix-review/checklist.md;
    "scripts/check.nu" = {
      source = ./agents/skills/nix-review/check.nu;
      executable = true;
    };
  };
};
```

Generated skills support every standard frontmatter field: `name` comes from
the attribute name; `description` is required; `license`, `compatibility`,
`metadata`, and experimental `allowed-tools` are optional. `instructions`
provides the Markdown body. `files` adds arbitrary relative resources. A skill
must use either a complete `source` directory or generated fields, never both.

## Additional files and validation

`agents.files` installs arbitrary source-backed or inline files relative to the
canonical root. It uses the same `source`, `text`, and `executable` schema and
is intended for shared context or future schema extensions:

```nix
agents.files."context/organization.md" = ./agents/context/organization.md;
```

The module rejects unsafe relative paths, duplicate installation targets,
documents without exactly one content source, malformed skill names, invalid
frontmatter lengths, missing source `SKILL.md` files, and generated resource
collisions with `SKILL.md`.
