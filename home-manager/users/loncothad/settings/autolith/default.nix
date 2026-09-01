{ lib, ... }:

let
  extensionDirectory = ./extensions;
  extensionFiles = lib.pipe (builtins.readDir extensionDirectory) [
    (lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".lisp" name))
    builtins.attrNames
    (map (name: extensionDirectory + "/${name}"))
  ];
in
{
  programs.autolith = {
    enable = true;
    model = "openrouter/qwen/qwen3.8-27b";
    reasoningEffort = "medium";
    extensions = extensionFiles;
  };
}
