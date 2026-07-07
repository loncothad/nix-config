args@{ pkgs, inputs, ... }:

{
  systems = [
    "x86_64-linux"
  ];

  perSystem =
    { ... }:
    {

    };

  flake = {
    formatter = pkgs.nixfmt;

    nixosConfigurations = import ../nixos args;

    nixosModules = {

    };

    # homeConfigurations = { }; # HM conf is tied with NixOS configuration as of now

    homeModules = {

    };

    diskoConfigurations = {
      imports = [
        ../disko
      ];
    };
  };
}
