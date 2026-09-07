#!/usr/bin/env nu

const repo_root = path self .
const nix_config = "extra-experimental-features = nix-command flakes"
const nix_flags = [
  "--extra-experimental-features"
  "nix-command"
  "--extra-experimental-features"
  "flakes"
]

def make-command [executable: string, args: list<string>, environment: record = {}] {
  let specification = {
    executable: $executable
    args: $args
    environment: $environment
  }
  $specification
}

def run-command [specification: record] {
  let executable = $specification.executable
  with-env $specification.environment {
    ^$executable ...$specification.args
    let exit_code = $env.LAST_EXIT_CODE
    if $exit_code != 0 {
      error make {
        msg: $"($executable) failed with exit code ($exit_code)"
      }
    }
  }
}

def --wrapped run-program [executable: string, ...args: string] {
  run-command (make-command $executable $args)
}

def --wrapped nix-command [...args: string] {
  make-command nix ($nix_flags | append $args) {
    NIX_CONFIG: $nix_config
  }
}

def --wrapped nh-command [...args: string] {
  make-command nh $args {
    NIX_CONFIG: $nix_config
    NH_OS_FLAKE: $repo_root
  }
}

def --wrapped rebuild-command [privileged: bool, ...args: string] {
  let feature_args = ["--option" "extra-experimental-features" "nix-command flakes"]
  let rebuild_args = $feature_args | append $args

  if $privileged {
    make-command sudo (["--preserve-env=NIX_CONFIG" "nixos-rebuild"] | append $rebuild_args) {
      NIX_CONFIG: $nix_config
    }
  } else {
    make-command nixos-rebuild $rebuild_args {
      NIX_CONFIG: $nix_config
    }
  }
}

def --wrapped run-nix [...args: string] {
  run-command (nix-command ...$args)
}

def --wrapped run-nh [...args: string] {
  run-command (nh-command ...$args)
}

def --wrapped run-gix [...args: string] {
  if (which gix | is-not-empty) {
    run-program gix ...$args
  } else {
    run-nix run nixpkgs#gitoxide -- ...$args
  }
}

def --wrapped run-rebuild [privileged: bool, ...args: string] {
  run-command (rebuild-command $privileged ...$args)
}

def --wrapped nh-os-command [action: string, host: string, --result-link, ...args: string] {
  mut nh_args = ["os" $action $repo_root "--hostname" $host]
  if $result_link {
    $nh_args = $nh_args | append ["--out-link" ($repo_root | path join result)]
  }
  nh-command ...($nh_args | append $args)
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
  scope commands
  | where {|entry| $entry.name starts-with "main " }
  | select name description
  | rename command description
  | update command {|entry| $entry.command | str replace "main " "" }
  | sort-by command
}

# Format all Nix files.
def "main fmt" [] {
  run-nix fmt $repo_root
}

# Open the repository development shell in Nushell.
def --wrapped "main shell" [...args: string] {
  run-nix develop $repo_root --command nu ...$args
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
  run-command (nh-os-command switch $selected ...$args)
}

# Build and set a host as the boot default without switching now.
def --wrapped "main boot" [--host (-H): string, ...args: string] {
  let selected = resolve-host $host
  run-command (nh-os-command boot $selected ...$args)
}

# Activate a host without adding a bootloader generation.
def --wrapped "main test" [--host (-H): string, ...args: string] {
  let selected = resolve-host $host
  run-command (nh-os-command test $selected ...$args)
}

# Build a host toplevel into ./result.
def --wrapped "main build" [--host (-H): string, ...args: string] {
  let selected = resolve-host $host
  run-command (nh-os-command build $selected --result-link ...$args)
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
  run-command (nh-os-command build-vm $selected --result-link ...$args)
}

# Diff ./result against the running system.
def "main diff" [] {
  let result = $repo_root | path join result
  if not ($result | path exists) {
    error make { msg: "no ./result — run './tasks.nu build' first" }
  }

  if (which nvd | is-not-empty) {
    run-program nvd diff /run/current-system $result
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
      run-program niri validate --config $temporary_config
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

# Show repository status with gix.
def "main status" [] {
  run-gix --no-verbose --repository $repo_root status --format simplified --untracked normal :
}

# Show the Git log.
def "main log" [count: int = 20] {
  run-program git -C $repo_root log --oneline --decorate -n ($count | into string)
}

# Fetch and rebase onto origin.
def "main pull" [] {
  run-program git -C $repo_root pull --rebase --autostash
}

# Push the current branch.
def --wrapped "main push" [...args: string] {
  run-program git -C $repo_root push ...$args
}

# Generate a changelog since the last tag with git-cliff.
def --wrapped "main changelog" [...args: string] {
  cd $repo_root
  if (which git-cliff | is-not-empty) {
    run-program git-cliff ...$args
  } else {
    run-nix run nixpkgs#git-cliff -- ...$args
  }
}

# Show jj status.
def "main jj-status" [] {
  run-program jj --repository $repo_root status
}

# Show the jj log.
def "main jj-log" [count: int = 20] {
  run-program jj --repository $repo_root log -n ($count | into string)
}
