# Autolith extensions

Store repository-owned Autolith extensions in this directory as Common Lisp
files ending in `.lisp`. Home Manager discovers them automatically and builds
`~/.config/autolith/init.lisp`, which loads each extension in lexicographic
filename order.

Use numeric filename prefixes when load order matters, for example
`10-provider.lisp` and `20-command.lisp`. Autolith evaluates these files in the
`AUTOLITH` package with the user's full privileges. New files must be tracked by
Git before the flake can see them.
