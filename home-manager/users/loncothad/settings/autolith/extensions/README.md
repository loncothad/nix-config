# Autolith extensions

Store repository-owned Autolith extensions below this directory as Common Lisp
files ending in `.lisp`. Nested directories are supported. Home Manager appends
one load form per extension to the generated `~/.config/autolith/init.lisp`, in
lexicographic path order.

Do not load these files manually from `config/init.lisp`; add each extension to
this tree once and let discovery include it. Duplicate paths contributed through
the Home Manager option are removed with an evaluation warning.

Use numeric filename prefixes when load order matters, for example
`providers/10-custom.lisp` and `commands/20-version.lisp`. Autolith evaluates
these files in the `AUTOLITH` package with the user's full privileges. New files
must be tracked by Git before the flake can see them.
