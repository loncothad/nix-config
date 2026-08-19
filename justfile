set shell := ["bash", "-euo", "pipefail", "-c"]
set dotenv-load := false

# Enable flakes even when they are not on in nix.conf.
export NIX_CONFIG := "extra-experimental-features = nix-command flakes"
nix := "nix --extra-experimental-features nix-command --extra-experimental-features flakes"
rebuild := "nixos-rebuild --option extra-experimental-features \"nix-command flakes\""

# Override with `just host=vega-small switch` or HOST=vega-small
host := env("HOST", `tr -d ' \n' </etc/hostname 2>/dev/null || echo kepler`)
flake := justfile_directory()
niri_dir := justfile_directory() / "home-manager/users/loncothad/settings/gui/niri"

[private]
default:
    @just --list --unsorted

# ── flake ────────────────────────────────────────────────────────────────────

[group('flake')]
[doc('Format all Nix files')]
fmt:
    {{ nix }} fmt {{ flake }}

[group('flake')]
[doc('Evaluate flake checks')]
check *args:
    {{ nix }} flake check --show-trace {{ flake }} {{ args }}

[group('flake')]
[doc('Show flake outputs')]
show *args:
    {{ nix }} flake show {{ flake }} {{ args }}

[group('flake')]
[doc('Print flake metadata and locked inputs')]
meta:
    {{ nix }} flake metadata {{ flake }}

[group('flake')]
[doc('List nixosConfigurations')]
hosts:
    {{ nix }} eval --raw {{ flake }}#nixosConfigurations --apply 'cf: builtins.concatStringsSep "\n" (builtins.attrNames cf) + "\n"'

[group('flake')]
[doc('Open a Nix REPL on this flake')]
repl:
    {{ nix }} repl --file '<nixpkgs>' --expr 'let flake = builtins.getFlake "{{ flake }}"; in { inherit flake; inherit (flake) nixosConfigurations inputs; }'

[group('flake')]
[doc('Evaluate the current host hostname (sanity check)')]
eval-host:
    {{ nix }} eval --raw {{ flake }}#nixosConfigurations.{{ host }}.config.networking.hostName

[group('flake')]
[doc('Evaluate a flake attribute, e.g. `just eval nixosConfigurations.kepler.config.system.stateVersion`')]
eval +attr:
    {{ nix }} eval --show-trace {{ flake }}#{{ attr }}

[group('flake')]
[doc('Update all flake inputs')]
update:
    {{ nix }} flake update --flake {{ flake }}

[group('flake')]
[doc('Update one or more flake inputs, e.g. `just update-input nixpkgs home-manager`')]
update-input +inputs:
    {{ nix }} flake update {{ inputs }} --flake {{ flake }}

[group('flake')]
[doc('Show what would change if flake.lock were updated')]
outdated:
    {{ nix }} flake update --flake {{ flake }} --dry-run

# ── system ───────────────────────────────────────────────────────────────────

[group('system')]
[doc('Build and switch to the host configuration')]
switch *args:
    sudo --preserve-env=NIX_CONFIG {{ rebuild }} switch --flake {{ flake }}#{{ host }} {{ args }}

[group('system')]
[doc('Build and set as the boot default without switching now')]
boot *args:
    sudo --preserve-env=NIX_CONFIG {{ rebuild }} boot --flake {{ flake }}#{{ host }} {{ args }}

[group('system')]
[doc('Activate without adding a bootloader generation')]
test *args:
    sudo --preserve-env=NIX_CONFIG {{ rebuild }} test --flake {{ flake }}#{{ host }} {{ args }}

[group('system')]
[doc('Build the host toplevel into ./result')]
build *args:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ flake }}"
    {{ rebuild }} build --flake {{ flake }}#{{ host }} {{ args }}

[group('system')]
[doc('Evaluate the host configuration without building')]
dry-build *args:
    {{ rebuild }} dry-build --flake {{ flake }}#{{ host }} {{ args }}

[group('system')]
[doc('Show the activation plan without applying it')]
dry-activate *args:
    sudo --preserve-env=NIX_CONFIG {{ rebuild }} dry-activate --flake {{ flake }}#{{ host }} {{ args }}

[group('system')]
[doc('Build a QEMU VM of the host configuration')]
build-vm *args:
    {{ rebuild }} build-vm --flake {{ flake }}#{{ host }} {{ args }}

[group('system')]
[doc('Diff the last build (./result) against the running system')]
diff:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ flake }}"
    if [[ ! -e result ]]; then
      echo "no ./result — run \`just build\` first" >&2
      exit 1
    fi
    if command -v nvd >/dev/null; then
      nvd diff /run/current-system result
    else
      {{ nix }} store diff-closures /run/current-system result
    fi

[group('system')]
[doc('List NixOS generations')]
generations:
    sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

[group('system')]
[doc('Roll back to the previous NixOS generation')]
rollback:
    sudo --preserve-env=NIX_CONFIG {{ rebuild }} rollback --flake {{ flake }}#{{ host }}

[group('system')]
[doc('Show why pkg-a depends on pkg-b in the current host closure')]
why-depends a b:
    {{ nix }} why-depends {{ flake }}#nixosConfigurations.{{ host }}.config.system.build.toplevel {{ a }} {{ b }}

# ── store ────────────────────────────────────────────────────────────────────

[group('store')]
[doc('Delete unused store paths (keep generations)')]
gc:
    {{ nix }} store gc --verbose

[group('store')]
[doc('Delete old generations, then collect garbage')]
gc-old:
    sudo --preserve-env=NIX_CONFIG nix-collect-garbage -d
    {{ nix }} store gc --verbose

[group('store')]
[doc('Hard-link identical store files')]
optimise:
    {{ nix }} store optimise

# ── pi ───────────────────────────────────────────────────────────────────────

[group('pi')]
[doc('Update pinned pi npm extensions (versions + hashes) in pkgs/pi-extensions/sources.json')]
pi-extensions-update *names:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ flake }}"
    script=misc/scripts/update-pi-extensions.nu
    if command -v nu >/dev/null && command -v npm >/dev/null; then
      nu "$script" {{ names }}
    else
      {{ nix }} shell nixpkgs#nushell nixpkgs#nodejs --command nu "$script" {{ names }}
    fi

[group('pi')]
[doc('List pinned pi npm extensions from sources.json')]
pi-extensions:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ flake }}"
    script=misc/scripts/update-pi-extensions.nu
    if command -v nu >/dev/null; then
      nu "$script" list
    else
      {{ nix }} shell nixpkgs#nushell --command nu "$script" list
    fi

# ── desktop ──────────────────────────────────────────────────────────────────

[group('desktop')]
[doc('Validate loncothad niri KDL (uses HOST for by-hostname include)')]
niri-validate:
    #!/usr/bin/env bash
    set -euo pipefail
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    cp "{{ niri_dir }}/config.kdl" "$tmp/config.kdl"
    host_kdl="{{ niri_dir }}/by-hostname/{{ host }}.kdl"
    if [[ -f "$host_kdl" ]]; then
      cp "$host_kdl" "$tmp/host-settings.kdl"
    else
      : >"$tmp/host-settings.kdl"
    fi
    if command -v niri >/dev/null; then
      niri validate --config "$tmp/config.kdl"
    else
      {{ nix }} shell nixpkgs#niri --command niri validate --config "$tmp/config.kdl"
    fi

# ── disko ────────────────────────────────────────────────────────────────────

[group('disko')]
[doc('Evaluate the Disko device tree for a host (default: kepler)')]
disko-eval host="kepler":
    {{ nix }} eval --json {{ flake }}#nixosConfigurations.{{ host }}.config.disko.devices

# ── git / jj ─────────────────────────────────────────────────────────────────

[group('git')]
[doc('Short git status')]
status:
    git -C {{ flake }} status -sb

[group('git')]
[doc('Git log (oneline)')]
log n="20":
    git -C {{ flake }} log --oneline --decorate -n {{ n }}

[group('git')]
[doc('Fetch and rebase onto origin')]
pull:
    git -C {{ flake }} pull --rebase --autostash

[group('git')]
[doc('Push the current branch')]
push *args:
    git -C {{ flake }} push {{ args }}

[group('git')]
[doc('Changelog since the last tag via git-cliff')]
changelog *args:
    #!/usr/bin/env bash
    set -euo pipefail
    cd "{{ flake }}"
    if command -v git-cliff >/dev/null; then
      git-cliff {{ args }}
    else
      {{ nix }} run nixpkgs#git-cliff -- {{ args }}
    fi

[group('git')]
[doc('jj status')]
jj-status:
    jj --repository {{ flake }} status

[group('git')]
[doc('jj log')]
jj-log n="20":
    jj --repository {{ flake }} log -n {{ n }}
