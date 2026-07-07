{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.virtualCamera;
in
{
  options = {
    services.virtualCamera = {
      enable = mkEnableOption "Virtual Camera support via v4l2loopback";

      cardLabel = mkOption {
        type = types.str;
        default = "Virtual Video Device";
        description = "The name of the virtual camera device presented to applications.";
      };

      videoNr = mkOption {
        type = types.nullOr types.int;
        default = null;
        example = 9;
        description = "The explicit /dev/videoX number to reserve. If null, the kernel picks the first available slot.";
      };
    };
  };

  config = mkIf cfg.enable {
    boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
    boot.kernelModules = [ "v4l2loopback" ];

    boot.extraModprobeConfig = ''
      options v4l2loopback \
        exclusive_caps=1 \
        card_label="${cfg.cardLabel}" \
        ${optionalString (cfg.videoNr != null) "video_nr=${toString cfg.videoNr}"}
    '';

    environment.systemPackages = [ pkgs.v4l-utils ];
  };
}
