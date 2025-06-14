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
    exec = "${pkgs.xdg-utils}/bin/xdg-open https://localhost:${toString config.services.portainer.port}";
    desktopName = "Docker Desktop";
    genericName = "Docker Desktop - docker web interface";
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
    # HACK: this portainer runs with OCI containers underneath - which makes it substantially slower
    # in the future, run this as normal service
    services.portainer = {
      enable = true;
      port = 9443;
    };
    environment.systemPackages = [
      docker-desktop
    ];
  };
}
