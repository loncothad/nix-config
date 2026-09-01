# Sub2API adapter

This flake exports a NixOS module for a complete self-hosted Sub2API stack.
Upstream does not provide a Nix flake, so its deployment repository is tracked
as the non-flake `sub2api-src` input for reproducible review of image,
environment, persistence, and service-graph changes.

## Project links

- Original repository: [Wei-Shaw/sub2api](https://github.com/Wei-Shaw/sub2api)
- Documentation: [upstream README](https://github.com/Wei-Shaw/sub2api#readme)
- Deployment documentation:
  [deploy/README.md](https://github.com/Wei-Shaw/sub2api/blob/main/deploy/README.md)

## Outputs and services

The adapter exports `nixosModules.default`, `nixosModules.sub2api`, and
`flakeModules.default`. Both NixOS outputs include the `quadlet-nix` module and
define:

```nix
virtualisation.oci-containers.namedContainers.sub2api
```

Enabling it creates the Sub2API application, PostgreSQL 18, and Redis 8 as
Podman Quadlets on the shared `selfhosted` network. Named volumes preserve
application, database, and Redis data. The application binds to
`127.0.0.1:8080` by default; use a TLS reverse proxy for public deployment and
enable direct firewall access only when intended.

PostgreSQL and Redis default to `mode = "owned"`, with their images and
server-only settings under `owned`. Select `mode = "shared"` to remove the
dependency container and configure the connection under `shared`. PostgreSQL
exposes host, port, user, database, and TLS mode; Redis exposes host and port.
Passwords remain in `environmentFile`.

## Secrets and configuration

Set `environmentFile` to a root-readable runtime secret file containing:

```text
POSTGRES_PASSWORD=...
ADMIN_PASSWORD=...
JWT_SECRET=...
TOTP_ENCRYPTION_KEY=...
```

`REDIS_PASSWORD` is optional. The same file may contain Sub2API's optional
OAuth, payment, mail, logging, and gateway environment variables. The module
generates a private runtime environment that maps the PostgreSQL secret to the
application's `DATABASE_PASSWORD` and supplies stable service hostnames.

Example:

```nix
virtualisation.oci-containers.namedContainers.sub2api = {
  enable = true;
  environmentFile = "/run/agenix/sub2api.env";
  adminEmail = "admin@example.com";
  timezone = "Europe/Istanbul";
};
```

## Root integration and updates

The root consumes this directory as the `sub2api-adapter` path input, imports
its flake-parts module for the named output, and composes
`nixosModules.default` into every NixOS system. No host enables the service by
default.

Update `sub2api-src` in this flake's lock after reviewing upstream's Compose
and environment examples for changes to images, required secrets, volumes,
ports, or dependencies. Refresh the root lock afterward.
