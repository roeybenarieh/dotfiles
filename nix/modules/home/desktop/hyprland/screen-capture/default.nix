{ namespace, lib, config, pkgs, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktop.hyprland.screenCapture;
  lua = lib.generators.mkLuaInline;
in
{
  options.${namespace}.desktop.hyprland.screenCapture = with types; {
    enable = mkBoolOpt false "Enable screen capture tools (screenshot + screen recorder).";
  };

  config = mkIf cfg.enable {
    # Ensure screenshot directory exists.
    home.file."Pictures/Screenshots/.keep".text = "";

    home.packages = with pkgs; [
      grimblast
      satty
      kooha
    ];

    wayland.windowManager.hyprland.settings.bind = [
      {
        _args = [
          "SUPER + SHIFT + S"
          (lua ''hl.dsp.exec_cmd("${pkgs.grimblast}/bin/grimblast --freeze save area - | ${pkgs.satty}/bin/satty --filename - --output-filename '${config.home.homeDirectory}/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png'")'')
        ];
      }
      { _args = [ "SUPER + SHIFT + R" (lua ''hl.dsp.exec_cmd("kooha")'') ]; }
    ];
  };
}
