{ namespace, lib, config, pkgs, ... }:

with lib;
with lib.${namespace};

let
  cfg = config.${namespace}.desktop.hyprland.ambxst;
in
{
  options.${namespace}.desktop.hyprland.ambxst = with types; {
    enable = mkBoolOpt false "Enable Ambxst shell integration for Hyprland.";
  };

  config = mkIf cfg.enable {
    programs.ambxst = {
      enable = true;
      settings = import ./settings.nix;
    };

    wayland.windowManager.hyprland = {
      extraConfig = ''
        source = ~/.local/share/ambxst/hyprland.conf
      '';

      settings = {
        bind = [
          "ALT, Tab, exec, ambxst run overview"
          "$mod, v, exec, ambxst run clipboard"
          "$mod, semicolon, exec, ambxst run emoji"
          "$mod SHIFT, s, exec, ambxst run screenshot"
        ];

        # TODO: I want to see the UI showing the brightness level
        bindel = [
          ", XF86MonBrightnessUp, exec, brightnessctl set 5%+"
          ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
        ];

        bindr = [
          "SUPER, Super_L, exec, ambxst run launcher"
        ];
      };
    };
  };
}
