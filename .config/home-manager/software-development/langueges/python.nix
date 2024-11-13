{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [ python312 ];
  programs.poetry = { enable = true; };
  home.file = {
    # TODO: change the path
    "${config.home.homeDirectory}/.config/pypoetry/config.toml".source =
      lib.mkForce ../../../../.config/pypoetry/config.toml;
  };
  home.sessionVariables = {
    PYTHONASYNCIODEBUG = 1; # for debuging asyncio application
  };
}
