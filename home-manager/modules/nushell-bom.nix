{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.nushell.bomScripts;

  # Extracts, cleans, and parses the JSON BOM from a single file path
  getDependencies =
    path:
    let
      content = builtins.readFile path;

      # builtins.split returns a mixed list of strings and match arrays.
      # For a string with both START and END tags, index 0 is the prefix,
      # index 1 is the START match, and index 2 is the raw payload.
      parts = builtins.split "# BOM-(START\n|END)" content;

      rawBom = if builtins.length parts >= 3 then builtins.elemAt parts 2 else "{}";

      # Strip out the Nushell comment syntax to yield raw JSON
      cleanBom = builtins.replaceStrings [ "# " "#" ] [ "" "" ] rawBom;

      parsed = builtins.fromJSON cleanBom;
    in
    parsed.dependencies or [ ];

  # Aggregate, flatten, and deduplicate package names from all provided scripts
  allDepNames = lib.unique (lib.flatten (map getDependencies cfg.scripts));

  # Resolve string names to actual nixpkgs derivations
  allPackages = map (name: pkgs.${name}) allDepNames;

  # Generate the Nushell code to source each script from the Nix store
  sourceCommands = lib.concatMapStringsSep "\n" (path: "source \"${path}\"") cfg.scripts;
in
{
  options.programs.nushell.bomScripts = {
    enable = lib.mkEnableOption "Nushell BOM script parsing and injection";

    scripts = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = "List of .nu script paths containing JSON BOM headers.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Inject resolved dependencies into the user's environment
    home.packages = allPackages;

    # Inject the scripts directly into the Nushell startup configuration
    programs.nushell.extraConfig = sourceCommands;
  };
}
