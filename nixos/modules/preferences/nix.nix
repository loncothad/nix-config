{ inputs, ... }:

let
  # Determinate's documented opt-outs for aggregate telemetry and Sentry crash reports.
  determinateTelemetryEnvironment = {
    DETSYS_IDS_TELEMETRY = "disabled";
    NIX_SENTRY_ENDPOINT = "";
  };
in

# nh
# nixd
# nixfmt
# statix
# nix-output-monitor
# envfs
# nix-ld
# direnv

{
  options = {

  };

  config = {
    environment.variables = determinateTelemetryEnvironment;

    nix = {
      registry.s.flake = inputs.self;

      settings = {
        experimental-features = [
          "nix-command"
          "flakes"
          "auto-allocate-uids"
        ];
        trusted-users = [
          "root"
          "@wheel"
        ];
        auto-optimise-store = true;
        fallback = true;
        keep-outputs = true;
        keep-derivations = true;
        connect-timeout = 5;
        http-connections = 32;
        always-allow-substitutes = true;
        builders-use-substitutes = true;
      };
    };

    nixpkgs.config = {
      allowUnfree = true;
      input-fonts.acceptLicense = true;
      permittedInsecurePackages = [
        "electron-39.8.10"
      ];
    };

    systemd.services.nix-daemon.environment = determinateTelemetryEnvironment;

    programs.nix-ld.enable = true;
  };
}
