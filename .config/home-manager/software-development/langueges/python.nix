{ config, pkgs, lib, ... }:

{
  # install python+pip
  # home.packages = with pkgs; [ python312 python312Packages.pip ];
  home.packages = with pkgs; [
    (python311.withPackages (pkgs: with pkgs; [
      pip
      fastapi
      pydantic
      requests
      pytest
    ]))
  ];

  # install 
  # home.sessionVariables = {
  #   LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
  #     pkgs.stdenv.cc.cc.lib
  #     pkgs.libz
  #   ];
  # };

  # poetry
  programs.poetry.enable = true;
  xdg.configFile."pypoetry/config.toml".source = ../../../../.config/pypoetry/config.toml;

  # python configuration
  home.sessionVariables = {
    PYTHONASYNCIODEBUG = 1; # for debuging asyncio application
  };
  home.shellAliases = { python = "python3.11"; };
}
