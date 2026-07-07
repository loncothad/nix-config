{ config, lib, ... }:

let
  cfg = config.programs.brave.xdgIntegration;

  baseMimeTypes = [
    "text/html"
    "application/xhtml+xml"
    "application/x-extension-htm"
    "application/x-extension-html"
    "application/x-extension-shtml"
    "application/x-extension-xht"
    "application/x-extension-xhtml"
    "x-scheme-handler/http"
    "x-scheme-handler/https"
    "x-scheme-handler/chrome"
    "x-scheme-handler/unknown"
  ];

  documentMimeTypes = [
    "application/pdf"
    "application/xml"
    "text/xml"
  ];

  ftpMimeTypes = [
    "x-scheme-handler/ftp"
  ];

  imageMimeTypes = [
    "image/webp"
    "image/png"
    "image/jpeg"
    "image/gif"
    "image/svg+xml"
  ];

  allMimeTypes =
    baseMimeTypes
    ++ (lib.optionals cfg.documents documentMimeTypes)
    ++ (lib.optionals cfg.ftp ftpMimeTypes)
    ++ (lib.optionals cfg.images imageMimeTypes);
in
{
  options = {
    programs.brave.xdgIntegration = {
      enable = lib.mkEnableOption "XDG MIME associations for Brave Browser";

      documents = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Associate document and markup MIME types (PDF, XML) with Brave.";
      };

      ftp = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Associate the FTP scheme handler with Brave.";
      };

      images = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Associate common web image MIME types (WebP, PNG, JPEG, GIF, SVG) with Brave.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.mimeApps.defaultApplications = lib.genAttrs allMimeTypes (_: "brave-browser.desktop");
  };
}
