# Agent notes

Read **[ARCHITECTURE.md](./ARCHITECTURE.md)** before changing this repo. It is
the map of flake outputs, NixOS/HM composition, hosts, and niri.

This file is only the working contract for agents.

## First reads

1. `ARCHITECTURE.md`
2. `justfile` — recipes for eval/rebuild/validate
3. The host you are touching under `nixos/hosts/<name>/`
4. `home-manager/users/loncothad/` if the change is user-facing
5. `flakes/README.md`, then `flakes/<name>/README.md`, if the change touches an
   external project adapter

## Commands

Run from the repo root. Flakes are forced on in the justfile even if `nix.conf`
does not enable them.

```bash
just                  # list recipes
just hosts            # flake nixosConfigurations
just host=kepler eval-host
just niri-validate    # loncothad niri KDL (HOST selects by-hostname)
just switch           # nixos-rebuild switch for current hostname
```

Override host with `HOST=kepler` or `just host=kepler …`.

Do not invent a second command surface. If a recipe is missing, add it to the
justfile instead of documenting a one-off `nix` invocation.

## Scripts

All scripts under `misc/scripts/` must be Nushell (`*.nu`), with `#!/usr/bin/env nu`.

Declare Nix packages the script needs in a TOML BOM so
`programs.nushell.bomScripts` can inject them. The parser in
`home-manager/modules/nushell-bom.nix` reads the first `# BOM-START` /
`# BOM-END` block:

```nu
#!/usr/bin/env nu

# BOM-START
# dependencies = [
#   "nodejs",
# ]
# BOM-END
```

- `dependencies` is a list of **nixpkgs attribute names** (`pkgs.${name}`).
- Every non-empty line inside the block must be a Nushell comment (`# …`).
- `# BOM-START` must be followed by a newline immediately (the start tag is
  `# BOM-START\n`).
- Do not add Python, Bash, or other script languages under `misc/scripts/`.

## Commits

Commit as you go. Do not pile unrelated edits into one commit at the end.

- One concern per commit (module, host, docs, scheduler, flake wiring, …).
- After a coherent unit of work is done and files are consistent, `git add`
  those paths and commit immediately. Then start the next unit.
- New files must be in the same commit that first references them.
- Do not amend, rebase, or rewrite history unless asked.
- Subject line is `section: what changed`. `section` is the area touched
  (host, module, flake, docs, …); the rest is a short description of the
  fix or change. Examples: `kepler: disable tuigreet doom background`,
  `profile: ISA plus x86_64Level`, `agents: require section subjects`.

## Edit rules

- Keep host diffs in `nixos/hosts/<name>` and `…/niri/by-hostname/<hostname>.kdl`.
- Repository-owned shared behavior goes in `nixos/modules` or
  `home-manager/modules`. For an imported project without an upstream flake,
  its package and project-specific modules stay together in `flakes/<name>/`.
- `loncothad` is imported on every system. Do not dump laptop-only packages into
  shared modules. Slim a host with `lib.mkForce` on
  `users.profiles.loncothad.homeManagerConfig`.
- Directories under `nixos/hosts/` are not systems until listed in
  `nixos/default.nix`.
- New files must be `git add`ed or Nix will not see them (`Path … is not
  tracked by Git`).
- Nix daemon is **Lix** (`nixos/modules/preferences/nix.nix`). Do not reintroduce
  CppNix-only settings (`configurable-impure-env`, `impure-env`).

## Project adapter flakes (`flakes/`)

Read **[`flakes/README.md`](./flakes/README.md)** before adding or changing an
adapter. It is the authoritative specification for adapter selection, concrete
layouts, output contracts, root wiring, naming, locking, and validation. Each
adapter must also have a README that records its role, upstream repository,
website and documentation when available, outputs, root integration, and
update procedure.

- Use flake-parts. Do not add a second module system or a one-off `outputs =`.
- File is `flake-parts.nix`, not `flake-module.nix`.
- If the imported upstream repository has no `flake.nix`, it **must** have an
  adapter here. Track its source as `inputs.<name>-src` (or another unambiguous
  `-src` name) with `flake = false`. Pass that input into a locally built
  package instead of fetching the project source from root `pkgs/`. For an OCI
  service stack with no local package, use the container-service contract in
  `flakes/README.md` and keep the source pin for deployment review.
- Keep a project's package and project-specific modules in the same adapter.
  Root `pkgs/`, `nixos/modules/`, and `home-manager/modules/` must not become
  alternate homes for non-flake upstream integrations.
- If upstream already provides a usable flake, consume it directly. A local
  supplemental module may still use a module-only adapter when it is large or
  intended for reuse.
- Core `path:` inputs follow the root `nixpkgs` and `flake-parts`. The adapter
  must still be evaluable on its own with its own lock.
- Package-producing inputs are mirrored as
  `pkgs.fromFlakes.<flake-name>.<flake-provided-package>`. Do not flatten them
  inside the overlay. Flat names are allowed only in the root `packages`
  output as convenience entry points.
- Export reusable modules from the adapter (`nixosModules.default` and/or
  `homeModules.default`). Wire project modules into system/HM composition and
  re-export them from the root; do not copy their implementation into a root
  barrel.
- A module's default package should come from the adapter's own package output
  (or be an explicit package option), so the adapter remains usable outside
  this repository's overlay.
- `git add` new adapter files before locking, then run
  `nix flake lock ./flakes/<name>` followed by `nix flake lock` at the root.
  Path inputs are invisible until Git tracks them.

## Out of scope unless asked

Do not rewrite `ARCHITECTURE.md` for a one-line change. Update it when you add
a host, move a module boundary, or change how users/HM attach.
