{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.jetbrains;
  pycharmPackage = pkgs.jetbrains.pycharm;
  openPycharmScript = pkgs.writeShellScriptBin "open-pycharm" ''
    set -euo pipefail
    
    # If argument provided → use it
    # Otherwise → use current directory
    SELECTEDPATH="''${1:-$PWD}"

    # run pycharm detached
    nohup ${getExe pycharmPackage} "$SELECTEDPATH" >/dev/null 2>&1 &
  '';
in
{
  options.${namespace}.jetbrains = with types; {
    enable = mkBoolOpt false "Whether or not to enable jetbrains applications.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs.jetbrains; [
      # idea-community # java, kotlin, scala, groovy
      pycharmPackage # python
      openPycharmScript
    ];
  };
}
