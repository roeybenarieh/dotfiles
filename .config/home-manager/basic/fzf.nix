{ pkgs, ... }:

{
  programs.fzf.enable = true;
  home.sessionVariables = {
    # preview fzf files with the bat(batcat) cli
    FZF_CTRL_T_OPTS = ''
      --preview '
        dir_path={}
        if [[ -d {} ]]; then 
          ${pkgs.tree}/bin/tree -L 3 {}
        else 
          ${pkgs.bat}/bin/bat -n --color=always {}
        fi
      '
      --bind 'ctrl-/:change-preview-window(down|hidden|)'
      --color header:italic
      --header 'CTRL-/ to change preview window'
    '';
    FZF_CTRL_R_OPTS = ''
      --preview 'echo {}' --preview-window up:3:hidden:wrap
      --bind 'ctrl-/:toggle-preview'
      --bind 'ctrl-y:execute-silent(echo -n {2..} | pbcopy)+abort'
      --color header:italic
      --header 'CTRL=/ to change preview window. CTRL-Y to copy command into clipboard'
    '';
    FZF_ALT_C_OPTS = " --preview 'tree -C {}'";
  };
}
