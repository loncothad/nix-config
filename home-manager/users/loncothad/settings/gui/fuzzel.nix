{ ... }:

{
  programs.fuzzel = {
    enable = true;

    settings = {
      main = {
        font = "Lilex:size=11";
        prompt = "'❯ '";
        placeholder = "'Search...'";

        lines = 8;
        width = 35;
        horizontal-pad = 24;
        vertical-pad = 14;
        inner-pad = 10;

        anchor = "center";
      };

      border = {
        width = 1;
        radius = 0;
      };

      colors = {
        # Hex RGBA values (without the leading '0x')
        background = "11111bff"; # Deep dark base background
        text = "a6adc8ff"; # Muted subtext gray
        prompt = "89b4faff"; # Soft accent blue prompt indicator
        placeholder = "585b70ff"; # Dim gray placeholder text
        input = "cdd6f4ff"; # High-contrast white for typing
        match = "f38ba8ff"; # Vibrant red for matching typed characters

        # Selection highlight overrides
        selection = "313244ff"; # Subtle gray block highlight on active selection
        selection-text = "89b4faff"; # High-contrast accent blue for selected entry
        selection-match = "f38ba8ff"; # Match highlights remain red under selection

        border = "313244ff"; # Dark gray border for a near-borderless style
      };
    };
  };
}
