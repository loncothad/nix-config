{ inputs, ... }:

{
  perSystem =
    { system, ... }:
    let
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [ (import ../pkgs { inherit inputs; }) ];
      };
    in
    {
      devShells.default = pkgs.mkShellNoCC {
        packages = with pkgs; [
          bottom
          btrfs-progs
          busybox
          cryptsetup
          dosfstools
          e2fsprogs
          fastfetch
          git
          gptfdisk
          helix
          iproute2
          iputils
          jujutsu
          kmod
          nh
          nushell
          parted
          pciutils
          procps
          usbutils
          util-linux
        ];
      };
    };
}
