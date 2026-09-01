# Notesnook Sync Server adapter

This flake exports a NixOS module for Notesnook's self-hosted synchronization
stack. Upstream does not provide a Nix flake, so the deployment repository is
tracked as the non-flake `notesnook-sync-server-src` input.

## Project links

- Original repository:
  [streetwriters/notesnook-sync-server](https://github.com/streetwriters/notesnook-sync-server)
- Website: [notesnook.com](https://notesnook.com/)
- Documentation:
  [upstream self-hosting README](https://github.com/streetwriters/notesnook-sync-server#using-docker)
- External-service examples:
  [upstream examples](https://github.com/streetwriters/notesnook-sync-server/tree/master/examples)

Upstream currently describes self-hosting as alpha and unsupported.

## Outputs and services

The adapter exports `nixosModules.default`,
`nixosModules.notesnook-sync-server`, and `flakeModules.default`. Both NixOS
outputs include `quadlet-nix`. The module defines:

```nix
virtualisation.oci-containers.namedContainers.notesnook-sync-server
```

It manages the core Identity, Sync API, SSE, and Monograph services as Podman
Quadlets. MongoDB and S3-compatible object storage each support explicit
`owned` and `shared` modes. Owned mode adds MongoDB, MinIO, and the MinIO bucket
initializer; shared mode omits the corresponding infrastructure containers.
The optional upstream themes, CORS proxy, and inbox profile is not enabled by
this core module.

All public ports bind to loopback by default. Each public endpoint normally
needs its own TLS reverse-proxy route, and Notesnook clients must be configured
with those endpoints.

## Secrets

`environmentFile` is loaded at runtime. It must contain:

```text
NOTESNOOK_API_SECRET=long-random-secret
```

Owned object storage additionally requires:

```text
MINIO_ROOT_USER=...
MINIO_ROOT_PASSWORD=...
```

Shared object storage instead requires:

```text
S3_ACCESS_KEY_ID=...
S3_ACCESS_KEY=...
```

Optional SMTP and Twilio variables documented in upstream's `.env` can be
placed in the same file. Shared MongoDB uses separate Identity and Sync runtime
files, each defining the service-specific `MONGODB_CONNECTION_STRING`; this
keeps credential-bearing URLs out of the Nix store. The MongoDB deployment must
be a replica set.

Example:

```nix
virtualisation.oci-containers.namedContainers.notesnook-sync-server = {
  enable = true;
  environmentFile = "/run/agenix/notesnook.env";
  instanceName = "personal-notes";
  publicUrls = {
    application = "https://app.notes.example.com";
    identity = "https://auth.notes.example.com";
    sync = "https://api.notes.example.com";
    monograph = "https://monograph.notes.example.com";
    attachments = "https://attachments.notes.example.com";
  };
};
```

## Root integration and updates

The root consumes this directory as `notesnook-sync-server-adapter`, follows
the root `nixpkgs`, `flake-parts`, and `quadlet-nix` inputs, imports its
flake-parts module, and composes its NixOS module into every system. No host
enables it by default.

Run `./tasks.nu update-adapter notesnook-sync-server` to update the upstream
source and adapter inputs, then validate upstream's Compose file and `.env`
against the service graph and options in `nixos.nix`.
