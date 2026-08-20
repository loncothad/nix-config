{ lib, ... }:

{
  options.flake.homeModules = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.deferredModule;
    default = { };
    description = ''
      Home Manager modules. Nested flakes contribute keys by exporting a
      flake-parts module that sets {option}`flake.homeModules.<name>`.
    '';
  };
}
