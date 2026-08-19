{ namespace, lib, config, pkgs, ... }:

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
    home.packages = with pkgs; [ rofi rofimoji ];

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
      { _args = [ "SUPER + Super_L" (lua ''hl.dsp.exec_cmd("${pkgs.rofi}/bin/rofi -show drun -config ${./applications-config.rasi}")'') ]; }
      { _args = [ "SUPER + semicolon" (lua ''hl.dsp.exec_cmd("${pkgs.rofimoji}/bin/rofimoji")'') ]; }
    ];
  };
}
