{ pkgs, namespace, lib, config, ... }:
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
    home.packages = with pkgs; [
      lsof
      sesh
    ];
    programs.tmux = {
      enable = true;
      secureSocket = false;
      newSession = true;
      plugins = with pkgs; [
        {
          plugin = tmuxPlugins.resurrect;
          extraConfig = ''
            set -g @resurrect-strategy-vim 'session'
            set -g @resurrect-strategy-nvim 'session'
            set -g @resurrect-capture-pane-contents 'on'

            resurrect_dir="$HOME/.tmux/resurrect"
            set -g @resurrect-dir $resurrect_dir
            set -g @resurrect-hook-post-save-all 'target=$(readlink -f $resurrect_dir/last); sed "s| --cmd .*-vim-pack-dir||g; s|/etc/profiles/per-user/$USER/bin/||g; s|/home/$USER/.nix-profile/bin/||g" $target | sponge $target'

            set -g @resurrect-capture-pane-contents 'on'
          '';
        }
        {
          plugin = tmuxPlugins.continuum;
          extraConfig = ''
            set -g @continuum-restore 'on'
            set -g @continuum-boot 'on'
            set -g @continuum-save-interval '5'
          '';
        }
        # tmuxPlugins.tmux-which-key
        # this cause an exception in the plugin: tmux source-file ~/.config/tmux/tmux.conf
      ];
      # requires vim-tmux-navigator in Neovim
      extraConfig = ''
        set -g mouse on

        # split-window verticaly
        unbind %
        bind J split-window -v
        # split-window horizontly
        unbind '"'
        bind L split-window -h

        # maximize
        bind -r m resize-pane -Z

        # vim like movement
        set-window-option -g mode-keys vi
        # bind h select-pane -L
        # bind j select-pane -D
        # bind k select-pane -U
        # bind l select-pane -R

        # staff according to vim-tmux-navigator github page
        bind-key -T copy-mode-vi 'C-h' select-pane -L
        bind-key -T copy-mode-vi 'C-j' select-pane -D
        bind-key -T copy-mode-vi 'C-k' select-pane -U
        bind-key -T copy-mode-vi 'C-l' select-pane -R
        bind-key -T copy-mode-vi 'C-\' select-pane -l


        # # v for selecting text and y for copy text
        bind-key -T copy-mode-vi 'v' send -X begin-selection
        bind-key -T copy-mode-vi 'y' send -X copy-selection

        # more intuitive text copying with mouse
        unbind -T copy-mode-vi MouseDragEnd1Pane
      '';
    };
    # xdg.configFile."tmux" = {
    #   source = ./tmux;
    #   onChange = "${getExe pkgs.tmux} source-file ${config.xdg.configHome}/tmux";
    # };
    programs.zsh.initContent = ''
      if command -v tmux &>/dev/null && [ -z "$TMUX" ]; then
        last_free_session=$(${getExe pkgs.tmux} ls -F "#{session_name}:#{session_attached}" 2>/dev/null \
          | awk -F: '$2 == 0 {print $1}' \
          | tail -n 1)

        if [ -n "$last_free_session" ]; then
          ${getExe pkgs.tmux} attach -t "$last_free_session"
        else
          ${getExe pkgs.tmux} new-session
        fi
      fi
    '';
    # zsh related
    # programs.zsh.oh-my-zsh.plugins = [ "tmux" ];
    # home.sessionVariables = {
    #   ZSH_TMUX_UNICODE = "true"; # enforce utf-8 for showing shell icons
    #   ZSH_TMUX_AUTOSTART_ONCE = "true"; # start tmux when session start
    #   ZSH_TMUX_FIXTERM = "true"; # set 256-color terminal if supported
    #   ZSH_TMUX_AUTOCONNECT = "true"; # start tmux session every terminal loggin
    #   ZSH_TMUX_AUTONAME_SESSION = "true";
    #   # ZSH_TMUX_CONFIG=$HOME/.config/tmux/tmux.conf;
    # };
  };
}
