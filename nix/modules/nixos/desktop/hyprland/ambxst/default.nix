{ namespace, lib, config, ... }:

with lib;
with lib.${namespace};

let
  cfg = config.${namespace}.desktop.hyprland.ambxst;
in
{
  options.${namespace}.desktop.hyprland.ambxst = with types; {
    enable = mkBoolOpt false "Enable Ambxst shell integration with Hyprland.";
  };

  config = mkIf cfg.enable {
    programs.ambxst = {
      enable = true;
      fonts = enabled;
    };

    snowfallorg.users.roey.home.config.${namespace}.desktop.hyprland.ambxst = enabled;
  };
}
