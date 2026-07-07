{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.polkit-agent-lxqt;
in
{
  options = {
    services.polkit-agent-lxqt = {
      enable = mkEnableOption "Polkit graphical authentication agent";
      package = mkOption {
        type = types.package;
        default = pkgs.lxqt.lxqt-policykit;
        description = "Target polkit interface implementation package.";
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.user.services.polkit-agent-lxqt = {
      Unit = {
        Description = "Polkit graphical authentication agent";
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${cfg.package}/bin/lxqt-policykit-agent";
        Restart = "on-failure";
        RestartSec = 3;
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
