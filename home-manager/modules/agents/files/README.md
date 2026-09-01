# Agent files

This directory is the repository-authored canonical agent tree. Files are
discovered recursively and installed below `$AGENTS_HOME` with their relative
paths preserved. No Nix option entry is needed for each file.

Use the standard layout where applicable:

```text
files/
├── AGENTS.md
├── SYSTEM.md
├── prompts/
│   └── <name>.md
└── skills/
    └── <name>/
        ├── SKILL.md
        ├── scripts/
        ├── references/
        └── assets/
```

Files named `README.md` are documentation and are not installed. Complete
skills should follow the [Agent Skills specification](https://agentskills.io/specification).
