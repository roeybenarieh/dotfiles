{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.claude;
in
{
  options.${namespace}.claude = with types; {
    enable = mkBoolOpt false "Whether or not to enable claude-desktop.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      claude-desktop-fhs # claude code
      claude-code # cli
      sox # for using voice

      # MCP related
      nodejs # needed for some MCPs
      pyright # needed in none pycharm environments for python analystics using LSP
      # gh # used by GitHub MCP server
    ];
    programs.chromium.extensions = [ "fcoeoabgfenejglbffodgkkbkcdhcgfn" ]; # claude chrome extention
  };
}
