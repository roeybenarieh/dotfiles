{ namespace, lib, config, pkgs, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktop.hyprland.applicationLauncher;
  lua = lib.generators.mkLuaInline;
in
{
  options.${namespace}.desktop.hyprland.applicationLauncher = with types; {
    enable = mkBoolOpt false "Enable the application launcher (rofi).";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ rofi ];

    xdg.configFile."rofi/applications-config.rasi".source = ../rofi/applications-config.rasi;

    wayland.windowManager.hyprland.settings.bind = [
      { _args = [ "SUPER + Super_L" (lua ''hl.dsp.exec_cmd("${pkgs.rofi}/bin/rofi -show drun -config ${../rofi/applications-config.rasi}")'') { release = true; } ]; }
    ];
  };
}
