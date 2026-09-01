{ config, lib, ... }:

let
  cfg = config.xdg.mimeApps;
  managedFiles = [
    "${config.xdg.configHome}/mimeapps.list"
    "${config.xdg.dataHome}/applications/mimeapps.list"
  ];
in
{
  options.xdg.mimeApps.resetOnActivation = lib.mkEnableOption ''
    resetting Home Manager's XDG MIME application files on every activation
  '';

  config = lib.mkIf cfg.resetOnActivation {
    xdg.mimeApps.enable = true;

    # Applications may replace these managed symlinks with mutable files.
    # Allow Home Manager to take ownership of the paths again on activation.
    xdg.configFile."mimeapps.list".force = true;
    xdg.dataFile."applications/mimeapps.list".force = true;

    home.activation.resetXdgMimeApps =
      lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ]
        ''
          run rm -f $VERBOSE_ARG -- ${lib.escapeShellArgs managedFiles}
        '';
  };
}
