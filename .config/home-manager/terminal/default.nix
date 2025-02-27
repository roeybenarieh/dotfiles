{ config, pkgs, ... }:

let
  # TODO: get a better solution according to what will be decided in the github issue
  # solution from: https://discourse.nixos.org/t/how-to-specify-programs-sqlite-for-command-not-found-from-flakes/22722/2
  # more info:
  # https://github.com/NixOS/nixpkgs/issues/171054
  # https://discourse.nixos.org/t/command-not-found-not-working/24023/3
  # https://www.youtube.com/watch?v=sLGoWAGklds
  #
  # To find the channel url I went in:
  # https://channels.nixos.org/ > nixos-22.05 > nixexprs.tar.gz
  # All the available channels you can browse https://releases.nixos.org
  nixos_tarball = pkgs.fetchzip {
    url = "https://releases.nixos.org/nixos/22.05/nixos-22.05.3737.3933d8bb912/nixexprs.tar.xz";
    sha256 = "sha256-+xhJb0vxEAnF3hJ6BZ1cbndYKZwlqYJR/PWeJ3aVU8k=";
  }
  ;
  # extract only the sqlite file
  programs-sqlite = pkgs.runCommand "program.sqlite" { } ''
    cp ${nixos_tarball}/programs.sqlite $out
  '';
in
{
  imports = [ ./zsh.nix ./alacritty.nix ./tmux.nix ];

  programs = {
    # helping fix up command syntax errors
    thefuck.enable = true;

    # autocompletion
    carapace.enable = true;

    command-not-found = {
      enable = true;
      dbPath = programs-sqlite;
    };
    nix-index = {
      enable = false;
    };
  };
  home.packages = with pkgs;
    [ xclip powershell ]; # better Ctrl+c Ctrl+v integration with terminal
  home.sessionVariables = {
    TERM = "alacritty";

    # command-not-found variables
    # TODO: make the auto installation work
    NIX_AUTO_RUN = "y"; # when typing a program not currently installed, automaticly will be installed via nix-shell.
    NIX_AUTO_RUN_INTERACTIVE = 1;
  }; # use alacritty as default terminal
  home.shellAliases = { powershell = "pwsh"; };
}
