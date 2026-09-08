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
      userName = "roey ben arieh";
      userEmail = "roey280404@gmail.com";
      extraConfig = {
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
