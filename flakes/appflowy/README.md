# AppFlowy Cloud adapter

This flake exports a NixOS module for a complete self-hosted AppFlowy Cloud
deployment. AppFlowy Cloud does not provide a Nix flake, so its upstream source
is tracked as the non-flake `appflowy-cloud-src` input.

## Project links

- Original repository:
  [AppFlowy-IO/AppFlowy-Cloud](https://github.com/AppFlowy-IO/AppFlowy-Cloud)
- Website: [appflowy.com](https://appflowy.com/)
- Documentation:
  [AppFlowy Cloud deployment](https://docs.appflowy.io/docs/documentation/appflowy-cloud/deployment)

## Outputs and services

The adapter exports `nixosModules.default`, `nixosModules.appflowy`, and
`flakeModules.default`. The NixOS module defines:

```nix
virtualisation.oci-containers.namedContainers.appflowy
```

Enabling it creates Podman containers for the Nginx entry point, AppFlowy Web,
AppFlowy Cloud API, GoTrue authentication, admin frontend, background worker,
search service, PostgreSQL with pgvector, Redis, and MinIO. AppFlowy AI is
optional. Named volumes persist the database, object storage, Redis data, and
search index.

The proxy binds to `127.0.0.1:8000` by default. Put it behind a TLS reverse
proxy for a public deployment, set `baseUrl` to that public URL, and override
`host` or `openFirewall` only when direct network access is intended.

## Secrets

`environmentFile` is loaded only at service start and must contain:

```text
POSTGRES_PASSWORD=...
GOTRUE_ADMIN_EMAIL=...
GOTRUE_ADMIN_PASSWORD=...
GOTRUE_JWT_SECRET=...
APPFLOWY_S3_ACCESS_KEY=...
APPFLOWY_S3_SECRET_KEY=...
```

Use URL-safe characters in `POSTGRES_PASSWORD`, or also provide its encoded
form as `POSTGRES_PASSWORD_URL_ENCODED`. Optional upstream variables such as
SMTP, OAuth, AssemblyAI, and `AI_OPENAI_API_KEY` may be placed in the same
file. Do not use shell or Compose interpolation in this file.

Example:

```nix
virtualisation.oci-containers.namedContainers.appflowy = {
  enable = true;
  environmentFile = "/run/agenix/appflowy.env";
  baseUrl = "https://appflowy.example.com";
  ai.enable = true;
};
```

## Root integration and updates

The root consumes this directory as the `appflowy-adapter` path input, imports its
flake-parts module for the named output, and composes `nixosModules.default`
into every NixOS system. No host enables the service by default.

Update `appflowy-cloud-src` in this flake's lock after reviewing upstream's
Compose file, deployment environment, and proxy configuration for changes to
the service graph or required variables. Refresh the root lock afterward.
