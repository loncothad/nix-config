{
  config,
  lib,
  ...
}:

let
  cfg = config.services.zellij-daemon;
  command = lib.escapeShellArgs (
    [
      (lib.getExe cfg.package)
      "web"
      "--start"
      "--ip"
      cfg.address
      "--port"
      (toString cfg.port)
    ]
    ++ lib.optionals (cfg.certificate != null && cfg.key != null) [
      "--cert"
      cfg.certificate
      "--key"
      cfg.key
    ]
    ++ cfg.extraArgs
  );
in
{
  options.services.zellij-daemon = {
    enable = lib.mkEnableOption "the Zellij web daemon (https://zellij.dev/documentation/web-client.html)";

    package = lib.mkOption {
      type = lib.types.package;
      default = config.programs.zellij.package;
      defaultText = lib.literalExpression "config.programs.zellij.package";
      description = "Zellij package used by the daemon.";
    };

    address = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address on which the Zellij web daemon listens.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8082;
      description = "Port on which the Zellij web daemon listens.";
    };

    certificate = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/agenix/zellij.crt";
      description = "Runtime path to the TLS certificate.";
    };

    key = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/agenix/zellij.key";
      description = "Runtime path to the TLS private key.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional arguments passed to zellij web --start.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.versionAtLeast (lib.getVersion cfg.package) "0.43.0";
        message = "services.zellij-daemon requires Zellij 0.43.0 or newer.";
      }
      {
        assertion = (cfg.certificate == null) == (cfg.key == null);
        message = "services.zellij-daemon.certificate and key must be configured together.";
      }
      {
        assertion = cfg.address == "127.0.0.1" || (cfg.certificate != null && cfg.key != null);
        message = "services.zellij-daemon requires TLS when listening outside 127.0.0.1.";
      }
    ];

    systemd.user.services.zellij-daemon = {
      Unit = {
        Description = "Zellij web daemon";
        Documentation = [ "https://zellij.dev/documentation/web-client.html" ];
      };
      Service = {
        ExecStart = command;
        Environment = [ "TERM=xterm-256color" ];
        Restart = "on-failure";
        RestartSec = 3;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
