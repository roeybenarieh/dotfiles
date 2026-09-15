{ namespace, lib, config, pkgs, inputs, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktop.hyprland.applicationLauncher;
  lua = lib.generators.mkLuaInline;
  papirus = pkgs.papirus-icon-theme;
  icon = name: "${papirus}/share/icons/Papirus/48x48/apps/${name}.svg";
in
{
  options.${namespace}.desktop.hyprland.applicationLauncher = with types; {
    enable = mkBoolOpt false "Enable the application launcher (rofi).";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ rofimoji papirus ];

    # Layout/behaviour only. Colors and font are intentionally left unset so
    # that Stylix's rofi target (autoEnabled) can theme them.
    programs.rofi = {
      enable = true;

      extraConfig = {
        modi = "drun";
        show-icons = true;
        display-drun = "";
        icon-theme = "Papirus";
        drun-display-format = "{name}";
        drun-use-desktop-cache = true;
        matching = "fuzzy";
        sort = true;
        sorting-method = "fzf";
        # Keep launch history so frequently/recently used apps float to the
        # top of the list when no search query is typed.
        disable-history = false;
        max-history-size = 25;
        kb-cancel = "Escape,F12";
        kb-move-char-back = "Control+b";
        kb-move-char-forward = "Control+f";
        kb-row-left = "Left";
        kb-row-right = "Right";
        kb-row-up = "Up,Control+p";
        kb-row-down = "Down,Control+n";
      };

      theme =
        let
          inherit (config.lib.formats.rasi) mkLiteral;
        in
        {
          window = {
            transparency = "real";
            location = mkLiteral "center";
            anchor = mkLiteral "center";
            fullscreen = false;
            width = mkLiteral "750px";
            x-offset = mkLiteral "0px";
            y-offset = mkLiteral "0px";
            enabled = true;
            margin = mkLiteral "0px";
            padding = mkLiteral "0px";
            border = mkLiteral "0px solid";
            border-radius = mkLiteral "12px";
            cursor = "default";
          };

          mainbox = {
            enabled = true;
            spacing = mkLiteral "20px";
            margin = mkLiteral "0px";
            padding = mkLiteral "20px";
            border = mkLiteral "0px solid";
            border-radius = mkLiteral "0px 0px 0px 0px";
            children = [ "inputbar" "listview" ];
          };

          inputbar = {
            enabled = true;
            spacing = mkLiteral "10px";
            margin = mkLiteral "0px";
            padding = mkLiteral "15px";
            border = mkLiteral "0px solid";
            border-radius = mkLiteral "10px";
            children = [ "prompt" "entry" ];
          };

          prompt.enabled = true;

          textbox-prompt-colon = {
            enabled = true;
            expand = false;
            str = "::";
          };

          entry = {
            enabled = true;
            cursor = mkLiteral "text";
            placeholder = "Search";
          };

          listview = {
            enabled = true;
            columns = 5;
            lines = 3;
            cycle = true;
            dynamic = true;
            scrollbar = false;
            layout = mkLiteral "vertical";
            reverse = false;
            fixed-height = true;
            fixed-columns = true;
            spacing = mkLiteral "0px";
            margin = mkLiteral "0px";
            padding = mkLiteral "0px";
            border = mkLiteral "0px solid";
            border-radius = mkLiteral "0px";
            cursor = "default";
          };

          scrollbar = {
            handle-width = mkLiteral "5px";
            border-radius = mkLiteral "0px";
          };

          element = {
            enabled = true;
            spacing = mkLiteral "15px";
            margin = mkLiteral "0px";
            padding = mkLiteral "20px 10px";
            border = mkLiteral "0px solid";
            border-radius = mkLiteral "10px";
            orientation = mkLiteral "vertical";
            cursor = mkLiteral "pointer";
          };

          element-icon = {
            size = mkLiteral "64px";
            cursor = mkLiteral "inherit";
          };

          element-text = {
            highlight = mkLiteral "inherit";
            cursor = mkLiteral "inherit";
            vertical-align = mkLiteral "0.5";
            horizontal-align = mkLiteral "0.5";
          };

          error-message = {
            padding = mkLiteral "15px";
            border = mkLiteral "2px solid";
            border-radius = mkLiteral "10px";
          };

          textbox = {
            vertical-align = mkLiteral "0.5";
            horizontal-align = mkLiteral "0.0";
            highlight = mkLiteral "none";
          };
        };
    };

    xdg.desktopEntries = {
      power-shutdown = {
        name = "Shutdown";
        exec = "systemctl -i poweroff";
        icon = icon "system-shutdown";
        categories = [ "System" ];
      };
      power-restart = {
        name = "Restart";
        exec = "systemctl -i reboot";
        icon = icon "system-reboot";
        categories = [ "System" ];
      };
      power-hibernate = {
        name = "Hibernate";
        exec = "systemctl -i hibernate";
        icon = icon "system-hibernate";
        categories = [ "System" ];
      };
      power-suspend = {
        name = "Suspend";
        exec = "systemctl -i suspend";
        icon = icon "system-suspend";
        categories = [ "System" ];
      };
      power-lock-screen = {
        name = "Lock Screen";
        exec = "hyprlock";
        icon = icon "system-lock-screen";
        categories = [ "System" ];
      };
    };

    wayland.windowManager.hyprland.settings.bind = [
      { _args = [ "SUPER + Super_L" (lua ''hl.dsp.exec_cmd("${config.programs.rofi.finalPackage}/bin/rofi -show drun")'') ]; }
      { _args = [ "SUPER + semicolon" (lua ''hl.dsp.exec_cmd("${pkgs.rofimoji}/bin/rofimoji")'') ]; }
    ];
  };
}
