{ namespace, lib, config, pkgs, ... }:

with lib;
with lib.${namespace};

let
  cfg = config.${namespace}.desktop.hyprland.ambxst;
  lua = lib.generators.mkLuaInline;
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

    wayland.windowManager.hyprland.extraConfig = ''
      loadfile(os.getenv("HOME") .. "/.local/share/ambxst/hyprland.lua")()
    '';

    wayland.windowManager.hyprland.settings = {
      bind = [
        { _args = [ "ALT + Tab"          (lua ''hl.dsp.exec_cmd("ambxst run overview")'')    ]; }
        { _args = [ "SUPER + V"          (lua ''hl.dsp.exec_cmd("ambxst run clipboard")'')   ]; }
        { _args = [ "SUPER + semicolon"  (lua ''hl.dsp.exec_cmd("ambxst run emoji")'')       ]; }
        { _args = [ "SUPER + SHIFT + S"  (lua ''hl.dsp.exec_cmd("ambxst run screenshot")'')  ]; }
      ];

      # TODO: I want to see the UI showing the brightness level
      bindel = [
        { _args = [ "XF86MonBrightnessUp"   (lua ''hl.dsp.exec_cmd("brightnessctl set 5%+")'') { repeating = true; locked = true; } ]; }
        { _args = [ "XF86MonBrightnessDown" (lua ''hl.dsp.exec_cmd("brightnessctl set 5%-")'') { repeating = true; locked = true; } ]; }
      ];

      bindr = [
        { _args = [ "SUPER + Super_L" (lua ''hl.dsp.exec_cmd("ambxst run launcher")'') { release = true; } ]; }
      ];
    };
  };
}
