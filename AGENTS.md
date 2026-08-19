# Agent notes

Read **[ARCHITECTURE.md](./ARCHITECTURE.md)** before changing this repo. It is
the map of flake outputs, NixOS/HM composition, hosts, and niri.

This file is only the working contract for agents.

## First reads

1. `ARCHITECTURE.md`
2. `justfile` — recipes for eval/rebuild/validate
3. The host you are touching under `nixos/hosts/<name>/`
4. `home-manager/users/loncothad/` if the change is user-facing

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

Declare Nix packages the script needs in a JSON BOM so
`programs.nushell.bomScripts` can inject them. The parser in
`home-manager/modules/nushell-bom.nix` reads the first `# BOM-START` /
`# BOM-END` block:

```nu
#!/usr/bin/env nu

# BOM-START
# {
#   "dependencies": [
#     "nodejs"
#   ]
# }
# BOM-END
```

- `dependencies` is a list of **nixpkgs attribute names** (`pkgs.${name}`).
- Every non-empty line inside the block must be a Nushell comment (`# …`).
- `# BOM-START` must be followed by a newline immediately (the start tag is
  `# BOM-START\n`).
- Do not add Python, Bash, or other script languages under `misc/scripts/`.

## Edit rules

- Keep host diffs in `nixos/hosts/<name>` and `…/niri/by-hostname/<hostname>.kdl`.
- Shared behavior goes in `nixos/modules` or `home-manager/modules`.
- `loncothad` is imported on every system. Do not dump laptop-only packages into
  shared modules. Slim a host with `lib.mkForce` on
  `users.profiles.loncothad.homeManagerConfig`.
- Directories under `nixos/hosts/` are not systems until listed in
  `nixos/default.nix`.
- New files must be `git add`ed or Nix will not see them (`Path … is not
  tracked by Git`).
- Nix daemon is **Lix** (`nixos/modules/preferences/nix.nix`). Do not reintroduce
  CppNix-only settings (`configurable-impure-env`, `impure-env`).

## Out of scope unless asked

Do not rewrite `ARCHITECTURE.md` for a one-line change. Update it when you add
a host, move a module boundary, or change how users/HM attach.
