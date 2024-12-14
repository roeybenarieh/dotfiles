# eza is a 'ls' alternative
{ config, pkgs, ... }:

{
  programs.eza = {
    enable = true;
    extraOptions = [
      "--git" # List each file's Git status if tracked or ignored
      "--icons" # Display icons next to file names
    ];
    # allow shell integrations only if the shell itself is enabled
    enableBashIntegration = config.programs.bash.enable;
    enableZshIntegration = config.programs.zsh.enable;
    enableFishIntegration = config.programs.fish.enable;
    enableNushellIntegration = config.programs.nushell.enable;
    enableIonIntegration = config.programs.ion.enable;
  };
  home.shellAliases = {
    ls = "eza";
    l = "ll";
  };
}
