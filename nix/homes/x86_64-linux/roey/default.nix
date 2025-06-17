{ pkgs, namespace, ... }:

{
  # imports = [
  #   stylix.homeManagerModules.stylix
  # ];

  ${namespace} = {
    cli.enable = true;
    desktop.enable = true;
    entertainment.enable = true;
    firefox.enable = true;
    git.enable = true;
    jetbrains.enable = true;
    neovim.enable = true;
    social.enable = true;
    terminal.enable = true;
    tmux.enable = true;
    tor.enable = true;
    vscode.enable = true;
    windows.enable = true;
    zsh.enable = true;
    networking.enable = true;
    containers.enable = true;
    python.enable = true;
    game-dev.enable = true;
    office.enable = true;
    services.enable = true;
  };

  # general
  nixpkgs.config.users.defaultUserShell = pkgs.zsh;

  home = {
    username = "roey";
    homeDirectory = "/home/roey";
    stateVersion = "24.05";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
