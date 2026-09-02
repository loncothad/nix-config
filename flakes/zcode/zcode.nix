{
  appimageTools,
  fetchurl,
  lib,
}:

let
  pname = "zcode";
  version = "3.10.2";

  src = fetchurl {
    url = "https://cdn-zcode.z.ai/zcode/electron/releases/${version}/linux-x64/ZCode-${version}-linux-x64.AppImage";
    hash = "sha256-b0utaKoaaQJuikXQqd8l8YaDvJpBevSDEF3L70SLqz8=";
  };

  appimageContents = appimageTools.extract {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraPkgs = pkgs: [
    pkgs.libnotify
    pkgs.libsecret
  ];

  extraInstallCommands = ''
    install -m 444 -D ${appimageContents}/zcode.desktop \
      "$out/share/applications/zcode.desktop"
    cp -r ${appimageContents}/usr/share/icons "$out/share/"

    substituteInPlace "$out/share/applications/zcode.desktop" \
      --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=zcode %U'
  '';

  meta = {
    description = "Official Z.AI agentic coding desktop application";
    homepage = "https://zcode.z.ai/en";
    downloadPage = "https://zcode.z.ai/en/docs/install";
    license = lib.licenses.unfree;
    mainProgram = "zcode";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
