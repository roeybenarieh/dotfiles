{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.stylix;
in
{
  options.${namespace}.stylix = with types; {
    enable = mkBoolOpt true "Whether or not to enable stylix.";
  };

  # more info can be found here:
  # https://stylix.danth.me/options/hm.html
  config.stylix = {
    # enabled only if enabled at options
    enable = cfg.enable;

    autoEnable = true;
    image = ./wallpaper.png;
    targets.neovim.enable = false;
    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
    };
    # run 'fc-cache -rf' when changing/installing fonts
    fonts = {
      sizes = {
        terminal = 15;
      };
      # the fonts given here are '<font_name> Regular', 
      # if you want to configure more fonts it has to be per application
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };
      serif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Serif";
      };
      sansSerif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Sans";
      };
    };
  };
}
