{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.software-development.languages.go;
in
{
  options.${namespace}.software-development.languages.go = with types; {
    enable = mkBoolOpt false "Whether or not to install go language.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      go

      # go REPL
      yaegi
      rlwrap
    ];

    home.shellAliases = {
      gorepl = "echo press Ctrl+D to exit.; ${getExe pkgs.rlwrap} ${getExe pkgs.yaegi}";
    };
  };
}
