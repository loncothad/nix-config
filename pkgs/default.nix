final: _prev: {
  piExtensions = final.callPackage ./pi-extensions { };
  tuigreet = final.callPackage ./tuigreet/package.nix { };
}
