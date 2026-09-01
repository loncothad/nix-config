{ lib, ... }:

let
  configDirectory = ./config;
  extensionDirectory = ./extensions;
  relativePath = file: lib.removePrefix "${toString configDirectory}/" (toString file);
  configFiles = builtins.sort (left: right: toString left < toString right) (
    lib.filesystem.listFilesRecursive configDirectory
  );
  configEntries = map (file: {
    inherit file;
    path = relativePath file;
  }) configFiles;
  isDocumentation = entry: builtins.baseNameOf entry.path == "README.md";

  extensionFiles = builtins.sort (left: right: toString left < toString right) (
    builtins.filter (file: lib.hasSuffix ".lisp" (toString file)) (
      lib.filesystem.listFilesRecursive extensionDirectory
    )
  );
  otherConfigFiles = lib.pipe configEntries [
    (builtins.filter (entry: entry.path != "init.lisp" && !(isDocumentation entry)))
    (map (entry: lib.nameValuePair entry.path entry.file))
    builtins.listToAttrs
  ];
in
{
  programs.autolith = {
    enable = true;
    model = "openrouter/openrouter/free";
    reasoningEffort = "none";
    extraConfig = builtins.readFile (configDirectory + "/init.lisp");
    extensions = extensionFiles;
    configFiles = otherConfigFiles;
  };
}
