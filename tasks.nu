#!/usr/bin/env nu

const repo_root = path self .
const nix_config = "extra-experimental-features = nix-command flakes"
const nix_flags = [
    "--extra-experimental-features"
    "nix-command"
    "--extra-experimental-features"
    "flakes"
]

const commands = [
    [group command description];
    [flake fmt "Format all Nix files"]
    [flake check "Evaluate flake checks"]
    [flake build-package "Build a package output without creating ./result"]
    [flake show "Show flake outputs"]
    [flake meta "Print flake metadata and locked inputs"]
    [flake hosts "List nixosConfigurations"]
    [flake repl "Open a Nix REPL on this flake"]
    [flake eval-host "Evaluate a host's hostname"]
    [flake eval "Evaluate a flake attribute"]
    [flake update "Update root flake inputs only"]
    [flake update-adapter "Update one adapter and its root path input"]
    [flake update-all "Update every adapter, then the root flake"]
    [flake update-input "Update one or more root flake inputs"]
    [flake outdated "Check all lock files for pending updates"]
    [system switch "Build and switch to a host configuration"]
    [system boot "Build and set a host as the boot default"]
    [system test "Activate a host without adding a boot generation"]
    [system build "Build a host toplevel into ./result"]
    [system dry-build "Evaluate a host without building"]
    [system dry-activate "Show a host's activation plan"]
    [system build-vm "Build a QEMU VM of a host"]
    [system diff "Diff ./result against the running system"]
    [system generations "List NixOS generations"]
    [system rollback "Roll back to the previous NixOS generation"]
    [system why-depends "Explain a dependency in the host closure"]
    [store gc "Delete unused store paths"]
    [store gc-old "Delete old generations, then collect garbage"]
    [store optimise "Hard-link identical store files"]
    [desktop niri-validate "Validate loncothad's niri KDL"]
    [disko disko-eval "Evaluate the Disko device tree for a host"]
    [git status "Show short Git status"]
    [git log "Show the Git log"]
    [git pull "Fetch and rebase onto origin"]
    [git push "Push the current branch"]
    [git changelog "Generate a changelog with git-cliff"]
    [git jj-status "Show jj status"]
    [git jj-log "Show the jj log"]
]

def --wrapped run-nix [...args: string] {
    with-env { NIX_CONFIG: $nix_config } {
        ^nix ...$nix_flags ...$args
        let exit_code = $env.LAST_EXIT_CODE
        if $exit_code != 0 {
            error make { msg: $"nix failed with exit code ($exit_code)" }
        }
    }
}

def --wrapped run-nh [...args: string] {
    with-env {
        NIX_CONFIG: $nix_config
        NH_OS_FLAKE: $repo_root
    } {
        ^nh ...$args
        let exit_code = $env.LAST_EXIT_CODE
        if $exit_code != 0 {
            error make { msg: $"nh failed with exit code ($exit_code)" }
        }
    }
}

def --wrapped run-rebuild [privileged: bool, ...args: string] {
    with-env { NIX_CONFIG: $nix_config } {
        let feature_args = ["--option" "extra-experimental-features" "nix-command flakes"]
        if $privileged {
            ^sudo --preserve-env=NIX_CONFIG nixos-rebuild ...$feature_args ...$args
        } else {
            ^nixos-rebuild ...$feature_args ...$args
        }
        let exit_code = $env.LAST_EXIT_CODE
        if $exit_code != 0 {
            error make { msg: $"nixos-rebuild failed with exit code ($exit_code)" }
        }
    }
}

def resolve-host [override?: string] {
    let fallback = try {
        open --raw /etc/hostname | str trim
    } catch {
        "kepler"
    }
    let candidate = if $override != null {
        $override
    } else {
        $env.HOST? | default $fallback
    }
    let selected = $candidate | str trim

    if $selected == "" {
        "kepler"
    } else {
        $selected
    }
}

def flake-ref [attribute?: string] {
    if $attribute == null {
        $repo_root
    } else {
        $"($repo_root)#($attribute)"
    }
}

def adapter-dir [name: string] {
    if not ($name =~ '^[a-z0-9][a-z0-9-]*$') {
        error make { msg: $"invalid adapter name: ($name)" }
    }

    let directory = $repo_root | path join flakes $name
    if not (($directory | path join flake.nix) | path exists) {
        error make { msg: $"unknown adapter: ($name)" }
    }
    $directory
}

def check-updates [flake_dir: path, label: string, temporary_dir: path] {
    let candidate_lock = $temporary_dir | path join $"($label).lock"
    print $"Checking ($label)"
    run-nix flake update --flake $flake_dir --reference-lock-file ($flake_dir | path join flake.lock) --output-lock-file $candidate_lock

    (open --raw ($flake_dir | path join flake.lock)) != (open --raw $candidate_lock)
}

# List the supported repository commands.
def main [] {
    print "Usage: ./tasks.nu <command> [arguments]\n\nHost-aware commands use the HOST environment variable or --host."
    $commands
}

# Format all Nix files.
def "main fmt" [] {
    run-nix fmt $repo_root
}

# Evaluate flake checks.
def --wrapped "main check" [...args: string] {
    run-nix flake check --show-trace $repo_root ...$args
}

# Build a package output without creating ./result.
def --wrapped "main build-package" [package: string, ...args: string] {
    run-nix build --no-link (flake-ref $package) ...$args
}

# Show flake outputs.
def --wrapped "main show" [...args: string] {
    run-nix flake show $repo_root ...$args
}

# Print flake metadata and locked inputs.
def "main meta" [] {
    run-nix flake metadata $repo_root
}

# List nixosConfigurations.
def "main hosts" [] {
    run-nix eval --raw (flake-ref nixosConfigurations) --apply 'cf: builtins.concatStringsSep "\n" (builtins.attrNames cf) + "\n"'
}

# Open a Nix REPL on this flake.
def "main repl" [] {
    let nix_path = $repo_root | to json
    let expression = $"let flake = builtins.getFlake ($nix_path); in { inherit flake; inherit \(flake\) nixosConfigurations inputs; }"
    run-nix repl --file '<nixpkgs>' --expr $expression
}

# Evaluate a host's configured hostname.
def "main eval-host" [--host (-H): string] {
    let selected = resolve-host $host
    run-nix eval --raw (flake-ref $"nixosConfigurations.($selected).config.networking.hostName")
}

# Evaluate a flake attribute.
def "main eval" [attribute: string] {
    run-nix eval --show-trace (flake-ref $attribute)
}

# Update root flake inputs only.
def --wrapped "main update" [...args: string] {
    run-nix flake update --flake $repo_root ...$args
}

# Update one flakes/<name> adapter and refresh its root path input.
def --wrapped "main update-adapter" [name: string, ...args: string] {
    let directory = adapter-dir $name
    run-nix flake update --flake $directory ...$args
    run-nix flake update $"($name)-adapter" --flake $repo_root ...$args
}

# Update every flakes/ adapter, then all root flake inputs.
def --wrapped "main update-all" [...args: string] {
    for adapter_flake in (glob ($repo_root | path join flakes '*' flake.nix) | sort) {
        run-nix flake update --flake ($adapter_flake | path dirname) ...$args
    }
    run-nix flake update --flake $repo_root ...$args
}

# Update one or more root flake inputs.
def "main update-input" [...inputs: string] {
    if ($inputs | is-empty) {
        error make { msg: "provide at least one flake input" }
    }
    run-nix flake update ...$inputs --flake $repo_root
}

# Show pending adapter and root lock updates without changing lock files.
def "main outdated" [] {
    let temporary_dir = mktemp --directory
    mut changed = false

    let failure = try {
        for adapter_flake in (glob ($repo_root | path join flakes '*' flake.nix) | sort) {
            let directory = $adapter_flake | path dirname
            let label = $directory | path basename
            if (check-updates $directory $label $temporary_dir) {
                $changed = true
            }
        }
        if (check-updates $repo_root root $temporary_dir) {
            $changed = true
        }
        null
    } catch { |error|
        $error
    } finally {
        rm --recursive --force --permanent $temporary_dir
    }
    if $failure != null {
        error make $failure
    }

    if $changed {
        print "Updates are available; run './tasks.nu update-all' to apply them"
    } else {
        print "All lock files are up to date"
    }
}

# Build and switch to a host configuration.
def --wrapped "main switch" [--host (-H): string, ...args: string] {
    let selected = resolve-host $host
    run-nh os switch $repo_root --hostname $selected ...$args
}

# Build and set a host as the boot default without switching now.
def --wrapped "main boot" [--host (-H): string, ...args: string] {
    let selected = resolve-host $host
    run-nh os boot $repo_root --hostname $selected ...$args
}

# Activate a host without adding a bootloader generation.
def --wrapped "main test" [--host (-H): string, ...args: string] {
    let selected = resolve-host $host
    run-nh os test $repo_root --hostname $selected ...$args
}

# Build a host toplevel into ./result.
def --wrapped "main build" [--host (-H): string, ...args: string] {
    let selected = resolve-host $host
    run-nh os build $repo_root --hostname $selected --out-link ($repo_root | path join result) ...$args
}

# Evaluate a host configuration without building.
def --wrapped "main dry-build" [--host (-H): string, ...args: string] {
    let selected = resolve-host $host
    run-rebuild false dry-build --flake (flake-ref $selected) ...$args
}

# Show a host's activation plan without applying it.
def --wrapped "main dry-activate" [--host (-H): string, ...args: string] {
    let selected = resolve-host $host
    run-rebuild true dry-activate --flake (flake-ref $selected) ...$args
}

# Build a QEMU VM of a host configuration.
def --wrapped "main build-vm" [--host (-H): string, ...args: string] {
    let selected = resolve-host $host
    run-nh os build-vm $repo_root --hostname $selected --out-link ($repo_root | path join result) ...$args
}

# Diff ./result against the running system.
def "main diff" [] {
    let result = $repo_root | path join result
    if not ($result | path exists) {
        error make { msg: "no ./result — run './tasks.nu build' first" }
    }

    if (which nvd | is-not-empty) {
        ^nvd diff /run/current-system $result
    } else {
        run-nix store diff-closures /run/current-system $result
    }
}

# List NixOS generations.
def "main generations" [] {
    run-nh os info
}

# Roll back to the previous NixOS generation.
def --wrapped "main rollback" [...args: string] {
    run-nh os rollback ...$args
}

# Show why pkg-a depends on pkg-b in a host closure.
def "main why-depends" [a: string, b: string, --host (-H): string] {
    let selected = resolve-host $host
    run-nix why-depends (flake-ref $"nixosConfigurations.($selected).config.system.build.toplevel") $a $b
}

# Delete unused store paths while keeping generations.
def "main gc" [] {
    run-nix store gc --verbose
}

# Delete old generations, then collect garbage.
def --wrapped "main gc-old" [...args: string] {
    run-nh clean all --no-gcroots ...$args
}

# Hard-link identical store files.
def "main optimise" [] {
    run-nix store optimise
}

# Validate loncothad's niri KDL, using HOST or --host for the include.
def "main niri-validate" [--host (-H): string] {
    let selected = resolve-host $host
    let niri_dir = $repo_root | path join home-manager users loncothad settings gui niri
    let temporary_dir = mktemp --directory
    let temporary_config = $temporary_dir | path join config.kdl

    let failure = try {
        cp ($niri_dir | path join config.kdl) $temporary_config
        let host_config = $niri_dir | path join by-hostname $"($selected).kdl"
        let temporary_host_config = $temporary_dir | path join host-settings.kdl
        if ($host_config | path exists) {
            cp $host_config $temporary_host_config
        } else {
            touch $temporary_host_config
        }

        if (which niri | is-not-empty) {
            ^niri validate --config $temporary_config
            let exit_code = $env.LAST_EXIT_CODE
            if $exit_code != 0 {
                error make { msg: $"niri validation failed with exit code ($exit_code)" }
            }
        } else {
            run-nix shell nixpkgs#niri --command niri validate --config $temporary_config
        }
        null
    } catch { |error|
        $error
    } finally {
        rm --recursive --force --permanent $temporary_dir
    }
    if $failure != null {
        error make $failure
    }
}

# Evaluate the Disko device tree for a host.
def "main disko-eval" [host: string = "kepler"] {
    run-nix eval --json (flake-ref $"nixosConfigurations.($host).config.disko.devices")
}

# Show short Git status.
def "main status" [] {
    ^git -C $repo_root status -sb
}

# Show the Git log.
def "main log" [count: int = 20] {
    ^git -C $repo_root log --oneline --decorate -n $count
}

# Fetch and rebase onto origin.
def "main pull" [] {
    ^git -C $repo_root pull --rebase --autostash
}

# Push the current branch.
def --wrapped "main push" [...args: string] {
    ^git -C $repo_root push ...$args
}

# Generate a changelog since the last tag with git-cliff.
def --wrapped "main changelog" [...args: string] {
    cd $repo_root
    if (which git-cliff | is-not-empty) {
        ^git-cliff ...$args
    } else {
        run-nix run nixpkgs#git-cliff -- ...$args
    }
}

# Show jj status.
def "main jj-status" [] {
    ^jj --repository $repo_root status
}

# Show the jj log.
def "main jj-log" [count: int = 20] {
    ^jj --repository $repo_root log -n $count
}
