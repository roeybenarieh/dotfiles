{ namespace, lib, config, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.tmux;
in
{
  options.${namespace}.tmux = with types; {
    enable = mkBoolOpt false "Whether or not to enable tmux.";
  };

  config = mkIf cfg.enable {
    programs.tmux = { enable = true; };
    # home.file = lib.mkForce {
    #   qtile_configs = {
    #     source = ../../tmux;
    #     target = ".config/tmux"; # path relative to $HOME
    #   };
    # };
    xdg.configFile."tmux" = {
      source = ./tmux;
      recursive = true;
    };
    home.sessionVariables = {
      ZSH_TMUX_UNICODE = "true"; # enforce utf-8 for showing shell icons
      ZSH_TMUX_AUTOSTART = "true"; # start tmux when session start
      ZSH_TMUX_FIXTERM = "true"; # set 256-color terminal if supported
      ZSH_TMUX_AUTOCONNECT = "false"; # start tmux session every terminal loggin
      ZSH_TMUX_CONFIG = "~/.config/tmux/tmux.conf";
    };
  };
}
