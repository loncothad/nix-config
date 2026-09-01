{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.home.mutableConfigFiles;
  homeDirectory = toString config.home.homeDirectory;
  configHome = toString config.xdg.configHome;
  defaultConfigPath = lib.removePrefix "${homeDirectory}/" configHome;

  validRelativePath =
    path:
    path != ""
    && !lib.hasPrefix "/" path
    && lib.all (component: component != "" && component != "." && component != "..") (
      lib.splitString "/" path
    );

  isSelected = target: lib.any (path: target == path || lib.hasPrefix "${path}/" target) cfg.paths;

  managedTargets = lib.sort (left: right: lib.stringLength left < lib.stringLength right) (
    lib.unique (
      map (file: file.target) (
        lib.filter (file: file.enable && isSelected file.target) (lib.attrValues config.home.file)
      )
    )
  );

  targetManifest = pkgs.writeText "home-manager-mutable-config-files" (
    lib.concatStringsSep "\n" managedTargets + lib.optionalString (managedTargets != [ ]) "\n"
  );

  stateManifest = "${config.xdg.stateHome}/home-manager/mutable-config-files";

  replaceManagedFile = pkgs.writeShellScript "replace-home-manager-mutable-config-file" ''
    set -eu

    target="$1"
    managed=false

    while IFS= read -r relativePath; do
      [[ -n "$relativePath" ]] || continue
      case "$target" in
        "$HOME/$relativePath" | "$HOME/$relativePath/"*)
          managed=true
          break
          ;;
      esac
    done < ${lib.escapeShellArg targetManifest}

    if $managed; then
      rm -rf -- "$target"
    elif [[ -n "''${HM_MUTABLE_FILES_FALLBACK_BACKUP_COMMAND:-}" ]]; then
      $HM_MUTABLE_FILES_FALLBACK_BACKUP_COMMAND "$target"
    elif [[ -n "''${HOME_MANAGER_BACKUP_EXT:-}" ]]; then
      backup="$target.$HOME_MANAGER_BACKUP_EXT"
      if [[ -e "$backup" || -L "$backup" ]]; then
        if [[ -n "''${HOME_MANAGER_BACKUP_OVERWRITE:-}" ]]; then
          rm -rf -- "$backup"
        else
          echo "Refusing to overwrite existing backup: $backup" >&2
          exit 1
        fi
      fi
      mv -- "$target" "$backup"
    else
      echo "Refusing to replace unmanaged path: $target" >&2
      exit 1
    fi
  '';
in
{
  options.home.mutableConfigFiles = {
    enable = lib.mkEnableOption ''
      mutable copies of Home Manager-managed configuration files
    '';

    paths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ defaultConfigPath ];
      defaultText = lib.literalExpression ''[ ".config" ]'';
      example = [
        ".config"
        ".gtkrc-2.0"
        ".ssh/config"
      ];
      description = ''
        Home-relative files and directory prefixes to materialize as mutable.
        Only paths that are also managed through `home.file` are affected.
        Runtime changes are discarded and replaced by the declarative version
        on the next Home Manager activation.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "${homeDirectory}/" configHome;
        message = "home.mutableConfigFiles requires xdg.configHome to be inside home.homeDirectory";
      }
      {
        assertion = lib.all validRelativePath cfg.paths;
        message = "home.mutableConfigFiles.paths must contain normalized paths relative to the home directory";
      }
    ];

    home.activation = {
      configureMutableConfigReplacement = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        export HM_MUTABLE_FILES_FALLBACK_BACKUP_COMMAND="''${HOME_MANAGER_BACKUP_COMMAND:-}"
        export HOME_MANAGER_BACKUP_COMMAND=${lib.escapeShellArg replaceManagedFile}
      '';

      cleanStaleMutableConfigFiles = lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
        if [[ -f ${lib.escapeShellArg stateManifest} ]]; then
          while IFS= read -r relativePath; do
            [[ -n "$relativePath" ]] || continue
            if ! grep -Fxq -- "$relativePath" ${lib.escapeShellArg targetManifest}; then
              run rm -rf $VERBOSE_ARG -- "$HOME/$relativePath"
            fi
          done < ${lib.escapeShellArg stateManifest}
        fi
      '';

      materializeMutableConfigFiles = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        while IFS= read -r relativePath; do
          [[ -n "$relativePath" ]] || continue

          sourcePath="$newGenPath/home-files/$relativePath"
          targetPath="$HOME/$relativePath"

          if [[ ! -e "$sourcePath" && ! -L "$sourcePath" ]]; then
            warnEcho "Mutable configuration source '$sourcePath' is missing; skipping"
            continue
          fi

          run rm -rf $VERBOSE_ARG -- "$targetPath"
          run mkdir -p $VERBOSE_ARG -- "$(dirname "$targetPath")"
          run cp -RL $VERBOSE_ARG -- "$sourcePath" "$targetPath"
          run chmod -R u+w -- "$targetPath"
        done < ${lib.escapeShellArg targetManifest}

        run install -Dm600 $VERBOSE_ARG ${lib.escapeShellArg targetManifest} ${lib.escapeShellArg stateManifest}
      '';
    };
  };
}
