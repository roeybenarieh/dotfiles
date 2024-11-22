{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [ python312 ];
  programs.poetry = { enable = true; };
  xdg.configFile."pypoetry/config.toml".source = ../../../../.config/pypoetry/config.toml;
  home.sessionVariables = {
    PYTHONASYNCIODEBUG = 1; # for debuging asyncio application
  };
}
