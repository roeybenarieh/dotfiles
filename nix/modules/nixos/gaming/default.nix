{ pkgs, namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.gaming;
in
{
  options.${namespace}.gaming = with types; {
    enable = mkBoolOpt false "Whether or not to enable gaming related apps.";
  };

  config = mkIf cfg.enable {
    programs.steam.enable = true;
    programs.steam.gamescopeSession.enable = true;
    programs.gamemode.enable = true;

    environment.systemPackages = with pkgs; [
      # protonup
      protonup-ng
      protonup-qt # protonup UI
    ];
    environment.sessionVariables = {
      STEAM_EXTRA_COMPAT_TOOLS_PATHS = "~/.steam/root/compatibilitytools.d";
    };
  };
}
 
