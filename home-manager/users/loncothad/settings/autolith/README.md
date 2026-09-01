# Autolith configuration

Module-managed concerns have their own directories, while `config/` is the
source-controlled pass-through Autolith configuration:

- `config/init.lisp` supplies the custom initialization body.
- `extensions/**/*.lisp` is discovered recursively and loaded after the
  custom initialization body.
- Other files below `config/` are installed under `~/.config/autolith/` with
  their relative paths preserved. This supports files such as `mcp.sexp`,
  `directory-scopes.sexp`, and `agents/*.sexp` without more Nix wiring.

Documentation files named `README.md` are not installed. Extension load order is
lexicographic by relative path, and duplicate extension paths are loaded once
with a warning during evaluation.
