{ config, lib, ... }:

let
  cfg = config.security.pam;

  limitsFor = domain: [
    {
      inherit domain;
      type = "-";
      item = "memlock";
      value = "unlimited";
    }
    {
      inherit domain;
      type = "-";
      item = "nofile";
      value = "1048576";
    }
    {
      inherit domain;
      type = "-";
      item = "nproc";
      value = "unlimited";
    }
    {
      inherit domain;
      type = "-";
      item = "locks";
      value = "unlimited";
    }
    {
      inherit domain;
      type = "-";
      item = "msgqueue";
      value = "unlimited";
    }
    {
      inherit domain;
      type = "-";
      item = "rtprio";
      value = "99";
    }
  ];
in
{
  options = {
    security.pam.enableUnlimited = lib.mkEnableOption "generous resource and system limits for all users, including root";
  };

  config = lib.mkIf cfg.enableUnlimited {
    security.pam.loginLimits = (limitsFor "*") ++ (limitsFor "root");
  };
}
