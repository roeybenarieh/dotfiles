# zoxide is a 'cd' alternative
{ config, pkgs, ... }:

{
  programs.zoxide = {
    enable = true;
    options = [
      "--cmd cd" # configure zoxide to be used as 'cd'
    ];
    # allow shell integrations only if the shell itself is enabled
    enableBashIntegration = config.programs.bash.enable;
    enableZshIntegration = config.programs.zsh.enable;
    enableFishIntegration = config.programs.fish.enable;
    enableNushellIntegration = config.programs.nushell.enable;
  };
}
