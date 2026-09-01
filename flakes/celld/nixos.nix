{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.celld;

  command = [
    (lib.getExe cfg.package)
    "--bucket"
    cfg.bucket
    "--listen"
    "${cfg.listenAddress}:${toString cfg.port}"
  ]
  ++ lib.optionals (cfg.endpoint != null) [
    "--endpoint"
    cfg.endpoint
  ]
  ++ lib.optionals (cfg.region != null) [
    "--region"
    cfg.region
  ]
  ++ lib.optionals (cfg.internalListen != null) [
    "--internal-listen"
    cfg.internalListen
  ]
  ++ lib.optionals (cfg.advertise != null) [
    "--advertise"
    cfg.advertise
  ]
  ++ lib.optional cfg.unsafePublicAdvertise "--unsafe-public-advertise"
  ++ lib.optional cfg.trustForwardedHeaders "--trust-forwarded-headers"
  ++ cfg.extraArgs;
in
{
  options.services.celld = {
    enable = lib.mkEnableOption "Celld distributed Durable Objects runtime (documentation: https://github.com/denoland/celld/blob/main/docs/README.md)";

    package = lib.mkPackageOption pkgs "celld" { };

    bucket = lib.mkOption {
      type = lib.types.str;
      example = "s3://my-cells-bucket";
      description = "Object-storage bucket and optional prefix used by this Celld fleet.";
    };

    endpoint = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "https://account.r2.cloudflarestorage.com";
      description = "Optional S3-compatible storage endpoint.";
    };

    region = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "auto";
      description = "Optional object-storage region.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address on which Celld serves Worker requests.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port on which Celld serves Worker requests.";
    };

    internalListen = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "10.0.0.12:8081";
      description = "Optional peer and operator listener in IP:PORT form.";
    };

    advertise = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "node-a.internal:8081";
      description = "Optional address at which peers can reach this node.";
    };

    unsafePublicAdvertise = lib.mkEnableOption "advertising a literal public IP";
    trustForwardedHeaders = lib.mkEnableOption "trusted reverse-proxy headers";

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/agenix/celld.env";
      description = ''
        Environment file containing credentials such as AWS_ACCESS_KEY_ID and
        AWS_SECRET_ACCESS_KEY. Do not place secrets in services.celld.environment.
      '';
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        RUST_LOG = "info";
        CELLD_MAX_RESIDENT_CELLS = "1000";
      };
      description = "Additional non-secret environment variables for Celld.";
    };

    stateDirectory = lib.mkOption {
      type = lib.types.strMatching "^[A-Za-z0-9_.-]+$";
      default = "celld";
      description = "Directory below /var/lib used for Celld's local state.";
    };

    cacheDirectory = lib.mkOption {
      type = lib.types.strMatching "^[A-Za-z0-9_.-]+$";
      default = "celld";
      description = "Directory below /var/cache used for downloaded assets.";
    };

    restartSec = lib.mkOption {
      type = lib.types.ints.positive;
      default = 10;
      description = ''
        Seconds to wait before restarting Celld. Keep this at least as long as
        the configured fleet lease lifetime.
      '';
    };

    openFirewall = lib.mkEnableOption "the public Worker listener in the firewall";

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional command-line arguments passed to Celld.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.bucket != "";
        message = "services.celld.bucket must not be empty.";
      }
      {
        assertion =
          cfg.advertise == null || cfg.internalListen != null || cfg.environment ? CELLD_INTERNAL_ADDR;
        message = "services.celld.advertise requires an internal listener.";
      }
    ];

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    systemd.services.celld = {
      description = "Celld distributed Durable Objects runtime";
      documentation = [
        "https://github.com/denoland/celld/blob/main/docs/README.md"
        "https://github.com/denoland/celld"
      ];
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      environment = cfg.environment // {
        CELLD_ASSET_CACHE_DIR = "/var/cache/${cfg.cacheDirectory}/assets";
        CELLD_WATCH = "/var/lib/${cfg.stateDirectory}/state";
      };

      unitConfig.StartLimitIntervalSec = 0;

      serviceConfig = {
        ExecStart = lib.escapeShellArgs command;
        EnvironmentFile = lib.optional (cfg.environmentFile != null) cfg.environmentFile;
        Restart = "always";
        RestartSec = cfg.restartSec;

        DynamicUser = true;
        StateDirectory = cfg.stateDirectory;
        CacheDirectory = cfg.cacheDirectory;
        UMask = "0077";

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        RestrictSUIDSGID = true;
      };
    };
  };
}
