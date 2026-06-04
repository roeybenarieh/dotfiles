{ namespace, lib, config, pkgs, ... }:

with lib;
with lib.${namespace};

let
  cfg = config.${namespace}.desktop.hyprland.ambxst;
in
{
  options.${namespace}.desktop.hyprland.ambxst = with types; {
    enable = mkBoolOpt false "Enable Ambxst shell integration for Hyprland.";
    settings = mkOpt (attrsOf anything) { } "Ambxst config settings. Each key maps to ~/.config/ambxst/config/<key>.json.";
  };

  config = mkIf cfg.enable {
    programs.ambxst = {
      enable = true;
      settings = cfg.settings;
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

        bindr = [
          "SUPER, Super_L, exec, ambxst run launcher"
        ];
      };
    };
  };
}
