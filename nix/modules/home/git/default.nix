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
    programs.git = {
      enable = true;
      settings = {
        user = {
          name = "roey ben arieh";
          email = "roey280404@gmail.com";
        };
        core.editor = "nvim";
        init.defaultBranch = "main";
        merge.ff = false;
      };
    };

    home.packages = with pkgs; [
      lazygit
      # gitbutler # doesnt work
      gitnuro
    ];
  };
}
