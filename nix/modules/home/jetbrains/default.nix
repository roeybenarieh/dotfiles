{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.jetbrains;
in
{
  options.${namespace}.jetbrains = with types; {
    enable = mkBoolOpt false "Whether or not to enable jetbrains applications.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs.jetbrains; [
      # idea-community # java, kotlin, scala, groovy
      pycharm-oss # python
    ];
  };
}
