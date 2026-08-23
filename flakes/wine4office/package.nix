{
  copyDesktopItems,
  coreutils,
  desktop-file-utils,
  fontconfig,
  gawk,
  gnused,
  lib,
  libnotify,
  makeDesktopItem,
  makeWrapper,
  pciutils,
  python3,
  qt6,
  src,
  stdenvNoCC,
  systemd,
  wine,
}:

let
  version = "0.1.11-rc.2";
  managerSource = "tools/wine4office-manager";
  python = python3.withPackages (ps: [
    ps.certifi
    ps.pefile
    ps.pyside6
    ps.zstandard
  ]);
  runtimePath = lib.makeBinPath [
    coreutils
    desktop-file-utils
    fontconfig
    gawk
    gnused
    libnotify
    pciutils
    systemd
    wine
  ];
  wrapperArgs = ''
    wrapperArgs=(
      "''${qtWrapperArgs[@]}"
      --set WINE4OFFICE_MANAGER_ROOT "$out"
      --set WINE4OFFICE_NIX_MANAGED 1
      --set WINE4OFFICE_WINE "${lib.getExe wine}"
      --prefix PATH : "${runtimePath}"
    )
  '';
in
stdenvNoCC.mkDerivation {
  pname = "wine4office";
  inherit version src;

  patches = [
    ./nix-managed-updates.patch
  ];

  nativeBuildInputs = [
    copyDesktopItems
    makeWrapper
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtwayland
  ];

  dontConfigure = true;
  dontBuild = true;
  dontWrapQtApps = true;

  desktopItems = [
    (makeDesktopItem {
      name = "wine4office-manager";
      desktopName = "Wine4Office Manager";
      comment = "Manage Wine4Office environments and shortcuts";
      exec = "wine4office-manager";
      icon = "wine4office-manager";
      categories = [
        "Settings"
      ];
    })
  ];

  installPhase = ''
    runHook preInstall

    root=$out
    install -d $out/bin $root/lib $root/icons $out/share/pixmaps

    ${wrapperArgs}

    install -m 0644 \
      ${managerSource}/wine4office_backend.py \
      ${managerSource}/wine4office_desktop.py \
      ${managerSource}/wine4office_i18n.py \
      ${managerSource}/wine4office_incident.py \
      ${managerSource}/wine4office_post_install.py \
      ${managerSource}/wine4office_qt.py \
      $root/lib/
    install -m 0755 \
      ${managerSource}/wine4office_manager.py \
      ${managerSource}/wine4office_preload.py \
      ${managerSource}/register-office-cloud-fonts.sh \
      $root/lib/
    cp -r ${managerSource}/translations $root/lib/
    install -m 0644 ${managerSource}/icons/* $root/icons/

    install -m 0755 ${managerSource}/wine4office-launcher \
      $out/bin/wine4office-launcher

    makeWrapper "${lib.getExe python}" $out/bin/wine4office-manager \
      "''${wrapperArgs[@]}" \
      --add-flags "$root/lib/wine4office_manager.py"
    makeWrapper "${lib.getExe python}" $out/bin/wine4office-preload-worker \
      "''${wrapperArgs[@]}" \
      --add-flags "$root/lib/wine4office_preload.py"

    patchShebangs $out/bin/wine4office-launcher $root/lib/register-office-cloud-fonts.sh
    wrapProgram $out/bin/wine4office-launcher "''${wrapperArgs[@]}"

    printf '%s\n' '${version}' > $root/VERSION
    printf '%s\n' '${wine.version}' > $root/WINE_VERSION
    printf '%s\n' stable > $root/UPDATE_CHANNEL
    : > $root/UPDATE_URL

    ln -s $root/icons/wine4office-manager.png \
      $out/share/pixmaps/wine4office-manager.png

    runHook postInstall
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck

    export HOME=$(mktemp -d)
    export QT_QPA_PLATFORM=offscreen
    export WINE4OFFICE_MANAGER_ROOT=$PWD/${managerSource}
    export WINE4OFFICE_NIX_MANAGED=1
    export WINE4OFFICE_WINE=${lib.getExe wine}
    ${lib.getExe python} ${managerSource}/wine4office_manager.py --smoke-test

    runHook postCheck
  '';

  passthru = {
    inherit wine;
  };

  meta = {
    description = "Run modern Microsoft Office on Linux without a Windows VM";
    homepage = "https://github.com/ttv20/wine4office";
    license = lib.licenses.lgpl21Plus;
    mainProgram = "wine4office-manager";
    platforms = [ "x86_64-linux" ];
  };
}
