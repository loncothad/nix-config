{ config, lib, ... }:

let
  cfg = config.programs.qimgv.xdgIntegration;

  imageMimeTypes = [
    "image/avif"
    "image/bmp"
    "image/gif"
    "image/heic"
    "image/heif"
    "image/jpeg"
    "image/jpg"
    "image/jxl"
    "image/png"
    "image/tiff"
    "image/webp"
    "image/x-bmp"
    "image/x-portable-anymap"
    "image/x-portable-bitmap"
    "image/x-portable-graymap"
    "image/x-portable-pixmap"
    "image/x-tga"
  ];

  associationMap = lib.genAttrs imageMimeTypes (_: "qimgv.desktop");
in
{
  options = {
    programs.qimgv.xdgIntegration = {
      enable = lib.mkEnableOption "XDG MIME associations for the qimgv image viewer";
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.mimeApps = {
      enable = true;
      defaultApplications = associationMap;
      associations.added = associationMap;
    };
  };
}
