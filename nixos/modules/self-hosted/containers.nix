{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.virtualisation.oci-containers.namedContainers;
in
{
  options.virtualisation.oci-containers.namedContainers = {
    enable = lib.mkEnableOption "the shared Podman runtime for self-hosted services";

    autoUpdate = {
      enable = lib.mkEnableOption "registry-based automatic container updates";

      dates = lib.mkOption {
        type = lib.types.str;
        default = "03:30";
        description = "systemd calendar expression for checking OCI image updates.";
      };

      randomizedDelaySec = lib.mkOption {
        type = lib.types.str;
        default = "30min";
        description = "Random delay applied to each OCI update check.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.backend = "podman";
    virtualisation.podman.enable = true;

    systemd.services.selfhosted-podman-network = {
      description = "Create the shared self-hosted Podman network";
      wantedBy = [ "multi-user.target" ];
      path = [ config.virtualisation.podman.package ];
      script = ''
        podman network exists selfhosted || podman network create selfhosted
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };

    systemd.services.selfhosted-container-update = lib.mkIf cfg.autoUpdate.enable {
      description = "Update self-hosted OCI containers";
      path = [ config.virtualisation.podman.package ];
      script = "podman auto-update";
      serviceConfig.Type = "oneshot";
    };

    systemd.timers.selfhosted-container-update = lib.mkIf cfg.autoUpdate.enable {
      description = "Periodically update self-hosted OCI containers";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.autoUpdate.dates;
        RandomizedDelaySec = cfg.autoUpdate.randomizedDelaySec;
        Persistent = true;
      };
    };

    environment.systemPackages = lib.mkIf cfg.autoUpdate.enable [ pkgs.podman ];
  };
}
