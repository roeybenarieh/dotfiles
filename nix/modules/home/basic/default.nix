{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.basic;
  gmail-icon = pkgs.fetchurl {
    url = "https://upload.wikimedia.org/wikipedia/commons/7/7e/Gmail_icon_%282020%29.svg";
    sha256 = "sha256-3hKd/5OcNBvmu1YXZXGclTYvAh25NuiKdFV2LmiH+wU=";
  };
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
      # xdg utils (e.g. xdg-open)
      xdg-utils

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
      cdold = "cd $OLDPWD";
      htop = "${getExe pkgs.btop}";
      open = "${pkgs.xdg-utils}/bin/xdg-open";
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
      cat = "${getExe pkgs.bat} --paging=never";
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
      tree = "eza --tree";
    };


    # fzf - fuzzy finder
    programs.fzf.enable = true;
    home.sessionVariables = {
      # preview fzf files with the bat(batcat) cli
      FZF_CTRL_T_OPTS = ''
        --preview '
          dir_path={}
          if [[ -d {} ]]; then 
            ${getExe pkgs.tree} -L 3 {}
          else 
            ${getExe pkgs.bat} -n --color=always {}
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

    # Define Gmail as a desktop application
    xdg.desktopEntries.gmail = {
      name = "Gmail";
      comment = "Google mail application";
      exec = ''xdg-open "https://mail.google.com/mail"'';
      terminal = false;
      type = "Application";
      icon = gmail-icon;
      mimeType = [ "x-scheme-handler/mailto" ];
    };
    # Make Gmail the default mailto handler
    xdg.mimeApps.defaultApplications = {
      "x-scheme-handler/mailto" = [ "gmail.desktop" ];
    };
  };
}
