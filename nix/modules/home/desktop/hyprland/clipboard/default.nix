{ namespace, lib, config, pkgs, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktop.hyprland.clipboard;
  lua = lib.generators.mkLuaInline;
  rofi = "${pkgs.rofi}/bin/rofi";
  cliphist = getExe pkgs.cliphist;
  wl-copy = "${pkgs.wl-clipboard}/bin/wl-copy";
in
{
  options.${namespace}.desktop.hyprland.clipboard = with types; {
    enable = mkBoolOpt false "Enable clipboard history management (cliphist + rofi picker).";
  };

  config = mkIf cfg.enable {
    services.cliphist = {
      enable = true;
      allowImages = true;
      # Keep 1000 entries as required (default is 750).
      extraOptions = [ "--max-items" "1000" ];
    };

    wayland.windowManager.hyprland.settings.bind = [
      {
        _args = [
          "SUPER + V"
          (lua ''hl.dsp.exec_cmd("${cliphist} list | ${rofi} -dmenu | ${cliphist} decode | ${wl-copy}")'')
        ];
      }
    ];
  };
}
