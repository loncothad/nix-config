# Agent notes

Read **[ARCHITECTURE.md](./ARCHITECTURE.md)** before changing this repo. It is
the map of flake outputs, NixOS/HM composition, hosts, and niri.

This file is only the working contract for agents.

## First reads

1. `ARCHITECTURE.md`
2. `tasks.nu` — Nushell commands for eval/rebuild/validate
3. The host you are touching under `nixos/hosts/<name>/`
4. `home-manager/users/loncothad/` if the change is user-facing
5. `flakes/README.md`, then `flakes/<name>/README.md`, if the change touches an
   external project adapter

## Commands

Run from the repo root. Flakes are forced on in `tasks.nu` even if `nix.conf`
does not enable them.

```bash
./tasks.nu                  # list commands
./tasks.nu hosts            # flake nixosConfigurations
./tasks.nu eval-host --host kepler
./tasks.nu niri-validate    # loncothad niri KDL (HOST selects by-hostname)
./tasks.nu update-adapter celld
./tasks.nu update-all       # nested adapter locks, then the root lock
./tasks.nu switch           # nh switch for current hostname
```

Override host with `HOST=kepler` or a host-aware command's `--host kepler`.

Do not invent a second command surface. If a recipe is missing, add it to the
Nushell script instead of documenting a one-off `nix` invocation.

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
- Indent all Nushell files with two spaces. Do not use tabs.
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
- Repository-owned shared behavior and single project modules go in
  `nixos/modules` or `home-manager/modules`. Create `flakes/<name>/` only when
  the integration directly depends on an external flake or Git repository, or
  owns more than one concern that must travel together (for example, a package
  plus both NixOS and Home Manager modules).
- `loncothad` is imported on every system. Do not dump laptop-only packages into
  shared modules. Slim a host with `lib.mkForce` on
  `users.profiles.loncothad.homeManagerConfig`.
- Directories under `nixos/hosts/` are not systems until listed in
  `nixos/default.nix`.
- New files must be `git add`ed or Nix will not see them (`Path … is not
  tracked by Git`).
- Keep global agent content in the Home Manager `agents` schema. Harness
  modules consume its records or canonical XDG directories and alone own
  vendor-specific discovery paths; do not add those paths to the shared schema.
- Put repository-authored global agent files under
  `home-manager/modules/agents/files/`; paths below that directory are
  preserved below `$AGENTS_HOME`.
- Nix daemon is **Determinate Nix**, supplied by the upstream `determinate`
  NixOS module. Do not set `nix.package` in repository modules; configure local
  daemon additions through `nix.settings`, which the Determinate module writes
  to its supported `nix.custom.conf` path.
- Define rootful OCI services with `virtualisation.quadlet`, using references
  to the shared `selfhosted` network and other Quadlet resources. Do not add
  containers through the nixpkgs `virtualisation.oci-containers.containers`
  backend. Quadlet-generated units are named `<resource>.service`, without a
  `podman-` prefix.

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
- If upstream already provides a usable flake and no local adapter is needed,
  consume it directly. A supplemental module by itself belongs in the main
  NixOS or Home Manager module directory. Use an adapter only when the local
  integration itself consumes that external flake or combines multiple
  integration concerns.
- Core `path:` inputs follow the root `nixpkgs` and `flake-parts`. The adapter
  must still be evaluable on its own with its own lock.
- Name core local path inputs `<project>-adapter`; reserve the unqualified
  project name for an upstream-provided flake input. Name a nested external
  flake input `<project>-upstream` and a non-flake Git input with a clear
  `-src` suffix.
- Package-producing inputs are mirrored as
  `pkgs.fromFlakes.<root-input-name>.<flake-provided-package>`. Do not flatten
  them inside the overlay. Flat names are allowed only in the root `packages`
  output as convenience entry points.
- Export reusable modules from the adapter (`nixosModules.default` and/or
  `homeModules.default`). Wire project modules into system/HM composition and
  re-export them from the root; do not copy their implementation into a root
  barrel.
- A module's default package should come from the adapter's own package output
  (or be an explicit package option), so the adapter remains usable outside
  this repository's overlay.
- `git add` new adapter files before locking, then run
  `./tasks.nu update-adapter <name>` to update its nested lock and corresponding
  root path input. Use `./tasks.nu update-all` to update every adapter before
  the root.
  Path inputs are invisible until Git tracks them.

## Out of scope unless asked

Do not rewrite `ARCHITECTURE.md` for a one-line change. Update it when you add
a host, move a module boundary, or change how users/HM attach.
