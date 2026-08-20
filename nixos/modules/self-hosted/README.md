# Self-hosted services

These modules are reusable and opt-in. No service is assigned to a host here:
the server sketches do not yet contain deployable hardware/networking or secret
configuration.

All locally added network services bind to `127.0.0.1` by default. Put a reverse
proxy in front of them, or deliberately set `host` and `openFirewall` when a
service must be reachable directly.

## Inventory

| Project | Nix interface | Delivery |
| --- | --- | --- |
| Rauthy | `services.rauthy` | Native `pkgs.rauthy` |
| useSend | `services.usesend` | Official OCI image plus PostgreSQL, Redis, and MinIO |
| Vaultwarden | `services.vaultwarden` | Upstream nixpkgs module |
| OxiCloud | `services.oxicloud` | Native `pkgs.oxicloud` |
| Tuwunel | `services.matrix-tuwunel` | Upstream nixpkgs module |
| OmniTools | `services.omni-tools` | Official OCI image |
| Checkmate | `services.checkmate` | Official OCI image plus MongoDB |
| Rybbit | `services.rybbit` | Official OCI images plus ClickHouse, PostgreSQL, and Redis |
| Homarr | `services.homarr` | Official OCI image |
| ntfy | `services.ntfy-sh` | Upstream nixpkgs module |
| RustDesk server | `services.rustdesk-server` | Upstream nixpkgs module |
| Scrutiny | `services.scrutiny` | Upstream nixpkgs module |
| AppFlowy | `programs.appflowy` | Native desktop client package |
| ConvertX | `services.convertx` | Native `pkgs.convertx` |
| NetBird | `services.netbird` and `services.netbird.server` | Upstream nixpkgs modules |

The linked AppFlowy repository is the desktop client. The separately maintained
AppFlowy Cloud stack is not silently substituted for it. Likewise, the linked
RustDesk client repository is represented on servers by nixpkgs' purpose-built
`rustdesk-server` package and module.

## Example

```nix
{
  services.rauthy = {
    enable = true;
    environmentFile = "/run/agenix/rauthy.env";
    environment = {
      LISTEN_SCHEME = "http";
      PUB_URL = "auth.example.net";
      PROXY_MODE = "true";
      TRUSTED_PROXIES = "127.0.0.1/32";
    };
  };

  services.oxicloud = {
    enable = true;
    environmentFile = "/run/agenix/oxicloud.env";
    environment.OXICLOUD_BASE_URL = "https://cloud.example.net";
  };

  services.convertx = {
    enable = true;
    environmentFile = "/run/agenix/convertx.env";
  };

  services.homarr = {
    enable = true;
    environmentFile = "/run/agenix/homarr.env";
  };

  services.selfhosted.containers.autoUpdate.enable = true;
}
```

The same container runtime and private `selfhosted` network are shared when any
of `usesend`, `omni-tools`, `checkmate`, `rybbit`, or `homarr` is enabled.
Persistent container data lives in named Podman volumes. Back those volumes up
before enabling automatic image updates.

## Secret files

Secret files use systemd/Podman `KEY=value` syntax and should come from agenix
or another runtime secret provider. They must not be Nix store files.

Rauthy's production file normally includes `HQL_SECRET_RAFT`,
`HQL_SECRET_API`, `ENC_KEYS`, and `ENC_KEY_ACTIVE`, plus SMTP credentials. Its
non-secret cluster, public URL, proxy, and WebAuthn settings can be placed in
`services.rauthy.environment`.

OxiCloud needs at least a production PostgreSQL connection:

```text
OXICLOUD_DB_CONNECTION_STRING=postgres://oxicloud:password@127.0.0.1/oxicloud
```

ConvertX should receive a stable `JWT_SECRET`. Homarr requires a 64-character
hex `SECRET_ENCRYPTION_KEY`. Checkmate requires `JWT_SECRET`; set
`services.checkmate.environment.CLIENT_HOST` to its public origin when the
module's generated loopback URL is not suitable.

useSend's file must point at the module's internal container names:

```text
POSTGRES_USER=usesend
POSTGRES_PASSWORD=replace-me
POSTGRES_DB=usesend
DATABASE_URL=postgresql://usesend:replace-me@usesend-postgres:5432/usesend
REDIS_URL=redis://usesend-redis:6379
NEXTAUTH_URL=https://send.example.net
NEXTAUTH_SECRET=replace-me
MINIO_ROOT_USER=replace-me
MINIO_ROOT_PASSWORD=replace-me
AWS_DEFAULT_REGION=us-east-1
```

Add one supported login provider and the SMTP/AWS credentials required by your
deployment.

Rybbit's shared file must include `BASE_URL`, `NEXT_PUBLIC_BACKEND_URL`,
`BETTER_AUTH_SECRET`, `CLICKHOUSE_DB`, `CLICKHOUSE_USER`,
`CLICKHOUSE_PASSWORD`, `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, and
`REDIS_PASSWORD`. Set the public backend URL in `NEXT_PUBLIC_BACKEND_URL`.

## Updates

Container applications use their stable `latest` tags by default. Enable
`services.selfhosted.containers.autoUpdate` to run `podman auto-update` on a
timer. Every managed container is labeled for registry updates; versioned
database tags remain on their selected release line unless the configured image
is changed.

Native services update through the flake's nixpkgs input. To deploy committed
lock-file updates automatically from a remote flake, configure:

```nix
services.selfhosted.autoUpdate = {
  enable = true;
  flake = "github:loncothad/nix-config";
  dates = "04:00";
};
```

This performs a `boot` upgrade and never reboots automatically. The remote
repository still needs to receive reviewed `flake.lock` updates, for example via
CI or `just update`.
