{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.game-dev;
in
{
  options.${namespace}.game-dev = with types; {
    enable = mkBoolOpt false "Whether or not to enable game-dev application.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      godot_4-mono
      jetbrains.rider # C#
    ];
    programs.vscode.profiles.default.extensions = with pkgs.vscode-extensions; [
      geequlim.godot-tools # extension for godot development
    ];
  };
}
