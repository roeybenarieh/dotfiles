{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.terminal;
in
{
  options.${namespace}.terminal = with types; {
    enable = mkBoolOpt false "Whether or not to enable terminal.";
  };

  config = mkIf cfg.enable {
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
            size = mkForce 25;
            # normal = jetbrainsMono "Regular";
            bold = jetbrainsMono "Bold";
            italic = jetbrainsMono "Italic";
            bold_italic = jetbrainsMono "Bold Italic";
          };

        cursor = { style = "Block"; };

        env = {
          TERM = "xterm-256color";
          WINIT_X11_SCALE_FACTOR = "1.0"; # better text size in multiplee monitorrs
        };

        general.live_config_reload = true;
      };
    };
    home.sessionVariables = {
      TERM = "alacritty";
      TERMINAL = "alacritty";
    };
    xdg.mimeApps = {
      enable = true;
      # to get mime type run: file -b --mime-type <file_name>
      defaultApplications = {
        "terminal" = "alacritty.desktop";
        "x-scheme-handler/terminal" = "alacritty.desktop";
      };
    };
    # FIX: not working in GNOME
    xdg.terminal-exec = {
      enable = false;
      package = pkgs.alacritty;
      settings = {
        GNOME = [
          # "com.raggesilver.BlackBox.desktop"
          # "org.gnome.Terminal.desktop"
          "alacritty.desktop"
          "Alacritty.desktop"
        ];
        default = [
          "alacritty.desktop"
          "Alacritty.desktop"
        ];
      };
    };
  };
}
