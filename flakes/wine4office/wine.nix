{
  fetchurl,
  lib,
  src,
  wineWow64Packages,
}:

let
  version = lib.removeSuffix "\n" (
    lib.removePrefix "Wine version " (builtins.readFile "${src}/VERSION")
  );
  wineGecko32 = fetchurl {
    url = "https://dl.winehq.org/wine/wine-gecko/2.47.4/wine-gecko-2.47.4-x86.msi";
    hash = "sha256-Js7MR3BrCRkI9/gUvdsHTGG+uAYzGOnvxaf3iYV3k9Y=";
  };
in
wineWow64Packages.unstableFull.overrideAttrs (old: {
  pname = "wine4office-wine";
  inherit src version;

  CPPFLAGS = "-I${src}/tools/wine4office-manager/packaging/linux-uapi";

  configureFlags = old.configureFlags ++ [ "--disable-tests" ];

  postConfigure = (old.postConfigure or "") + ''
    grep -q '^#define HAVE_LINUX_NTSYNC_H 1$' include/config.h
    for feature in SONAME_LIBFREETYPE SONAME_LIBFONTCONFIG SONAME_LIBGNUTLS SONAME_LIBDBUS_1; do
      grep -q "^#define $feature " include/config.h
    done
  '';

  postInstall = old.postInstall + ''
    ln -s ${wineGecko32} \
      $out/share/wine/gecko/wine-gecko-2.47.4-x86.msi

    grep -aq '/dev/ntsync' $out/bin/wineserver
    test -f $out/lib/wine/x86_64-unix/winewayland.so
  '';

  meta = old.meta // {
    description = "Wine fork focused on running modern Microsoft Office";
    homepage = "https://github.com/ttv20/wine4office";
    license = lib.licenses.lgpl21Plus;
    mainProgram = "wine";
    platforms = [ "x86_64-linux" ];
  };
})
