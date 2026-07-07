{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.programs.mark-shot;
  jsonFormat = pkgs.formats.json { };
in
{
  options = {
    programs.mark-shot = {
      enable = mkEnableOption "mark-shot, a high-performance screenshot and annotation tool";

      package = mkOption {
        type = types.package;
        description = "The mark-shot package to use. Can be pulled from your custom overlay or flake input.";
      };

      settings = mkOption {
        type = jsonFormat.type;
        default = { };
        example = literalExpression ''
          {
            annotation = {
              defaultTool = "move";
              fullscreenDefaultTool = "laser";
              defaultColor = "#FF4D4D";
            };
            save = {
              pathTemplate = "{pictures}/mark-shot/mark-shot-{datetime}.png";
            };
            windows = {
              tray.enabled = true;
              hotkeys.capture = "Ctrl+Alt+S";
            };
          }
        '';
        description = ''
          Configuration options written directly to ~/.config/mark-shot/config.json.
          See upstream documentation for all supported keys.
        '';
      };

      extensions = mkOption {
        type = types.nullOr jsonFormat.type;
        default = null;
        example = literalExpression ''
          {
            commands = [
              {
                name = "OCR selection";
                command = "ocr-tool {image}";
                saveImage = true;
              }
            ];
          }
        '';
        description = ''
          Custom extension commands written directly to ~/.config/mark-shot/extensions.json.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.configFile = {
      "mark-shot/config.json" = mkIf (cfg.settings != { }) {
        source = jsonFormat.generate "mark-shot-config.json" cfg.settings;
      };

      "mark-shot/extensions.json" = mkIf (cfg.extensions != null) {
        source = jsonFormat.generate "mark-shot-extensions.json" cfg.extensions;
      };
    };
  };
}
