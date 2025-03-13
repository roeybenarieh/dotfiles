{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.basic;
in
{
  options.${namespace}.basic = with types; {
    enable = mkBoolOpt true "Whether or not to enable basic apps.";
  };

  config = mkIf cfg.enable {
    ${namespace} = {
      stylix.enable = true;
      nix.enable = true;
    };

    # Let Home Manager install and manage itself.
    programs.home-manager.enable = true;

    # general shit
    home.packages = with pkgs; [
      # file system
      tree
      baobab # disk usage GUI
      nautilus # file explorer

      # system diagnostic
      btop # like htop but better

      # networking related
      curl
      wget

      # text editing
      vim
      xclip # sharing system clipboard with terminal clipboard

      # utils
      tldr

      # debug programs
      ltrace
      strace

      # archive management
      zip
      unzip
      gnutar

      # fun
      neofetch
      cmatrix
      asciiquarium
      lolcat
      cowsay
    ];
    home.shellAliases = {
      c = "clear";
      htop = "btop";
      open = "xdg-open";
    };
    # set nauilus as default folder explorer
    xdg.mimeApps.defaultApplications = {
      "inode/directory" = "nautilus";
    };


    # bat - cat alternative
    programs.bat = {
      enable = true;
      extraPackages = with pkgs.bat-extras; [
        prettybat # pretty print files(format the files before printing)
        batman # use bat to display man pages
        batpipe # integrate bat with other tools
      ];
    };
    home.shellAliases = {
      cat = lib.getExe pkgs.bat;
    };


    # eza - ls alternative
    programs.eza = {
      enable = true;
      extraOptions = [
        "--git" # List each file's Git status if tracked or ignored
        "--icons" # Display icons next to file names
        "--group" # Display the group of the resourcd
      ];
    };
    home.shellAliases = {
      l = "ls -lh"; # defaulty l = "ls -lFh", and -F doesnt exists in eza.
    };


    # fzf - fuzzy finder
    programs.fzf.enable = true;
    home.sessionVariables = {
      # preview fzf files with the bat(batcat) cli
      FZF_CTRL_T_OPTS = ''
        --preview '
          dir_path={}
          if [[ -d {} ]]; then 
            ${lib.getExe pkgs.tree} -L 3 {}
          else 
            ${lib.getExe pkgs.bat} -n --color=always {}
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


    # zoxide - cd alternative
    programs.zoxide = {
      enable = true;
      options = [
        "--cmd cd" # configure zoxide to be used as 'cd'
      ];
    };

    # enable numlock on default
    xsession.numlock.enable = true;
  };
}
