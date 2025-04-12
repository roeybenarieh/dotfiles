{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.git;
in
{
  options.${namespace}.git = with types; {
    enable = mkBoolOpt false "Whether or not to enable git.";
  };

  config = mkIf cfg.enable {
    # install git itself
    programs.git.enable = true;

    # set the git config file
    xdg.configFile = {
      "git" = {
        source = ./git;
        recursive = true;
      };
    };

    home.packages = with pkgs; [
      lazygit
      # gitbutler # doesnt work
      gitnuro
    ];
  };
}
