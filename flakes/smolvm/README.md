# smolvm adapter

This adapter packages the upstream [smolvm](https://github.com/smol-machines/smolvm)
OCI microVM engine and exposes a NixOS module that registers its containerd shim.
The upstream flake is wrapped here so the package and runtime module remain
available through the repository's `flakes/` boundary while smolvm is not yet
packaged in nixpkgs.

The adapter exports the upstream package set (`smolvm`, `libkrun`, and
`libkrunfw`), the `smolvm` overlay, and `nixosModules.default` (also available
as `nixosModules.smolvm`). Enabling `virtualisation.smolvm` installs the engine
and shim, configures containerd with `io.containerd.smolvm.v2`, and provisions
`/var/lib/smolvm` for runtime state. A Linux host with KVM is required.

The root flake follows the adapter's nixpkgs and flake-parts inputs, mirrors its
packages under `pkgs.fromFlakes.smolvm-adapter`, re-exports the module, and
enables it on the `kepler` host. Existing OCI services remain on their current
Quadlet definitions; migrating them to smolvm is intentionally deferred.

To update the upstream pin, run `./tasks.nu update-adapter smolvm` after adding
this directory to Git. The adapter has its own lockfile so it can also be
checked independently.

- [smolvm source repository](https://github.com/smol-machines/smolvm)
- [smolvm deployment documentation](https://github.com/smol-machines/smolvm/tree/main/deploy)
