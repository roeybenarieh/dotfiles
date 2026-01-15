{ pkgs, namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.docker;
  docker-icon = pkgs.fetchurl {
    url = "https://www.svgrepo.com/show/353659/docker-icon.svg";
    sha256 = "sha256-hrMQippiv+WsiaSzLn95B+W0V0ODAKtzH09kAYP762k=";
  };
  docker-desktop = pkgs.makeDesktopItem {
    name = "Docker Desktop";
    exec = getExe pkgs.podman-desktop;
    desktopName = "Docker Desktop";
    genericName = "Docker Desktop - podman desktop";
    categories = [ "Development" ];
    icon = docker-icon;
  };
in
{
  options.${namespace}.docker = with types; {
    enable = mkBoolOpt false "Whether or not to enable docker.";
  };

  config = mkIf cfg.enable {
    virtualisation.docker = {
      enable = true;
      enableOnBoot = false;
    };
    environment.systemPackages = with pkgs; [ podman-desktop ] ++ [ docker-desktop ];
  };
}
