{ namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktop.hyprland.windowSwitcher;
in
{
  options.${namespace}.desktop.hyprland.windowSwitcher = with types; {
    enable = mkBoolOpt false "Enable hyprshell GTK4 window switcher (Alt+Tab).";
  };

  config = mkIf cfg.enable {
    programs.hyprshell = {
      enable = true;
      settings.windows = {
        enable = true;
        switch = {
          enable = true;
          modifier = "alt";
          key = "Tab";
          filter_by = [ ];
        };
      };
    };
  };
}
