{ pkgs, ... }: {
  # install nerdfont
  # run 'fc-cache -rf' when changing/installing fonts
  home.packages = with pkgs; [ nerd-fonts.jetbrains-mono ];

  # install alacritty
  programs.alacritty = {
    enable = true;

    # alacritty configuration file
    settings = {
      window = {
        padding = {
          x = 4;
          y = 8;
        };
        decorations = "full";
        startup_mode = "Windowed";
        title = "Alacritty";
        dynamic_title = true;
        decorations_theme_variant = "None";
      };

      font =
        let
          jetbrainsMono = style: {
            family = "JetBrainsMono Nerd Font";
            inherit style;
          };
        in
        {
          # size = 15;
          # normal = jetbrainsMono "Regular";
          bold = jetbrainsMono "Bold";
          italic = jetbrainsMono "Italic";
          bold_italic = jetbrainsMono "Bold Italic";
        };

      cursor = { style = "Block"; };

      env = { TERM = "xterm-256color"; };

      general.live_config_reload = true;
    };
  };
}
