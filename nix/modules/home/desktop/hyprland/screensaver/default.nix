{ namespace, lib, config, pkgs, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktop.hyprland.screensaver;
  lua = lib.generators.mkLuaInline;
in
{
  options.${namespace}.desktop.hyprland.screensaver = with types; {
    enable = mkBoolOpt false "Enable hyprlock screensaver/lock screen.";
  };

  config = mkIf cfg.enable {
    programs.hyprlock = {
      enable = true;
      settings = {
        general = {
          disable_loading_bar = true;
          grace = 0;
          hide_cursor = true;
          no_fade_in = false;
        };

        label = [
          {
            # Time
            text = ''cmd[update:1000] echo "$(date +"%H:%M")"'';
            color = "rgba(255, 255, 255, 0.9)";
            font_size = 96;
            font_family = "Roboto Condensed Bold";
            position = "0, 80";
            halign = "center";
            valign = "center";
          }
          {
            # Date
            text = ''cmd[update:60000] echo "$(date +"%A, %B %d")"'';
            color = "rgba(255, 255, 255, 0.6)";
            font_size = 20;
            font_family = "Roboto Condensed";
            position = "0, -10";
            halign = "center";
            valign = "center";
          }
        ];

        input-field = {
          size = "300, 50";
          position = "0, -200";
          halign = "center";
          valign = "center";
          dots_center = true;
          fade_on_empty = true;
          fade_timeout = 2000;
          placeholder_text = "<span foreground='##ffffff99'>Password</span>";
          hide_input = false;
          rounding = 12;
        };
      };
    };

    wayland.windowManager.hyprland.settings.bind = [
      { _args = [ "XF86ScreenSaver" (lua ''hl.dsp.exec_cmd("hyprlock")'') ]; }
      { _args = [ "SUPER + L"       (lua ''hl.dsp.exec_cmd("hyprlock")'') ]; }
    ];
  };
}
