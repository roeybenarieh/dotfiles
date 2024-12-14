{ config, pkgs, ... }:

{
  imports = [ ./zsh.nix ./alacritty.nix ./tmux.nix ];
  programs.thefuck.enable = true;
  home.packages = with pkgs;
    [ xclip powershell ]; # better Ctrl+c Ctrl+v integration with terminal
  home.sessionVariables = {
    TERM = "alacritty";
  }; # use alacritty as default terminal
  home.shellAliases = { powershell = "pwsh"; };
}
