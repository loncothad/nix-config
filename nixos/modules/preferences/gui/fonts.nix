{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.preferences.fonts;
in
{
  options = {
    preferences.fonts = {
      enable = mkEnableOption "font preferences";
    };
  };

  config = mkIf cfg.enable {
    fonts = {
      enableDefaultPackages = true;
      fontDir.enable = true;

      fontconfig = {
        enable = true;

        antialias = true;
        hinting = {
          enable = true;
          style = "slight";
        };
        subpixel = {
          rgba = "rgb";
          lcdfilter = "default";
        };

        defaultFonts = {
          sansSerif = [
            "IBM Plex Sans"
            "IBM Plex Sans JP"
            "IBM Plex Sans KR"
            "IBM Plex Sans SC"
            "IBM Plex Sans TC"
          ];

          serif = [
            "IBM Plex Serif"
            "Noto Serif CJK JP"
            "Noto Serif CJK KR"
            "Noto Serif CJK SC"
            "Noto Serif CJK TC"
          ];

          monospace = [
            "Lilex"
            "IBM Plex Mono"
            "Symbols Nerd Font"
            "CCSymbols"
          ];

          emoji = [
            "Noto Color Emoji"
            "Last Resort"
            "Symbola"
          ];
        };
      };

      packages = with pkgs; [
        # Main fonts that are used
        ibm-plex
        lilex
        noto-fonts-color-emoji
        noto-fonts-cjk-serif

        nerd-fonts.symbols-only
        ccsymbols

        last-resort
        symbola
        gyre-fonts

        # Cool non-main fonts
        input-fonts
        uiua386
        terminus_font

        # Unique
        ultimate-oldschool-pc-font-pack

        material-symbols # The modern variable font iteration of Google Material Design Icons
        material-icons # The classic static icon font set
      ];
    };
  };
}
# console =
#     let
#       getFont = font: "${pkgs.terminus_font}/share/consolefonts/${font}.psf.gz";
#     in
#     {
#       earlySetup = true;
#       packages = lib.mkDefault [ pkgs.terminus_font ];
#       keyMap = "ruwin_alt_sh-UTF-8";
#       font = getFont (if HiDPI.isEnabled then "ter-v32n" else "ter-v16n");
#     };

# console.font = "${pkgs.notonoto-console}/share/fonts/truetype/notonoto-console/NOTONOTOConsole-Regular.ttf";
# console.useXkbConfig = true;

# material-design-icons
# material-icons
# fira-code
# fira-code-symbols

# nerd-fonts.symbols-only

# https://github.com/name-snrl/nixos-configuration/blob/master/nixos/desktop/console.nix

# unifont
# symbola

# gyre-fonts
# caladea
# carlito

#https://github.com/name-snrl/nixos-configuration/blob/master/nixos/desktop/fonts.nix
