{ config, pkgs, lib, ... }:

{
  # install python+pip
  home.packages = with pkgs; [ python312 python312Packages.pip ];

  # poetry
  programs.poetry = { enable = true; };
  xdg.configFile."pypoetry/config.toml".source = ../../../../.config/pypoetry/config.toml;

  # python configuration
  home.sessionVariables = {
    PYTHONASYNCIODEBUG = 1; # for debuging asyncio application
  };
}
