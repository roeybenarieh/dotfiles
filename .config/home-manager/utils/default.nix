{ pkgs, config, ... }:
{
  home.packages = with pkgs;[
    krita # GUI paint app
    stremio # streaming app
    obsidian # notes managment
  ];

  # TODO: enable all plugins, and in search combine: programs + windows + obsidian + calculator
  # * probably put all of this in the qtile folder
  # programs.rofi = {
  #   plugins = with pkgs; [
  #     rofi-obsidian # integrate obsidian vaults with rofi
  #     rofi-calc # calculator inside rofi
  #   ];
  #   terminal = config.home.sessionVariables.TERM;
  # };

  # can run stremio via: https://sourcegraph.com/github.com/IceDBorn/IceDOS/-/blob/hardware/server/default.nix
  # home.sessionVariables = {
  # SERVER_URL = "http://127.0.0.1:11470";
  # IPADDRESS = "127.0.0.1";
  # WEBUI_LOCATION = "http://127.0.0.1:8080";
  # };
}
