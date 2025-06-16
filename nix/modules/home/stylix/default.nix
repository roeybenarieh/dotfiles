{ namespace, lib, config, pkgs, inputs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.stylix;
in
{
  options.${namespace}.stylix = with types; {
    enable = mkBoolOpt false "Whether or not to enable stylix.";
  };

  # more info can be found here:
  # https://stylix.danth.me/options/hm.html
  config.stylix = {
    # enabled only if enabled at options
    enable = cfg.enable;

    autoEnable = true;
    image = "${inputs.assets}/wallpaper1.png";
    polarity = "dark";
    targets = {
      neovim.enable = false;
      firefox.profileNames = [ "default" ];
      vscode.profileNames = [ "default" ];
    };
    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 24;
    };
    # run 'fc-cache -rf' when changing/installing fonts
    fonts = {
      sizes = {
        terminal = 15;
        popups = 15;
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
