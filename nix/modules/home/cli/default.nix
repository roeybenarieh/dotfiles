{ system, namespace, inputs, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.cli;
  programs-sqlite-db = inputs.flake-programs-sqlite.packages.${system}.programs-sqlite;
in
{
  options.${namespace}.cli = with types; {
    enable = mkBoolOpt false "Whether or not to enable cli utilities.";
  };

  config = mkIf cfg.enable {
    programs = {
      # helping fix up command syntax errors
      pay-respects = {
        enable = true;
        options = [ "--alias thefuck --alias tf --alias f" ];
      };

      # autocompletion
      carapace.enable = true;

      command-not-found = {
        enable = true;
        dbPath = programs-sqlite-db;
      };

      # for more info: https://opencode.ai/docs/models
      opencode = enabled;
    };
    home.shellAliases.ai = "opencode";
    xdg.configFile."opencode" = {
      source = ./opencode;
      recursive = true;
    };
    home.packages = with pkgs; [
      xclip # better Ctrl+c Ctrl+v integration with terminal
      stow # manage dotfiles
      just # just cli
    ];
    home.sessionVariables = {
      # command-not-found: when typing a program not currently installed, automaticly will be installed via nix-shell.
      NIX_AUTO_RUN = "y";
      NIX_AUTO_RUN_INTERACTIVE = "";
    };
  };
}
