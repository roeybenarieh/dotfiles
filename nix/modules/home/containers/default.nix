{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.containers;
in
{
  options.${namespace}.containers = with types; {
    enable = mkBoolOpt false "Whether or not to enable containers related tools.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs;
      [
        # containers
        docker # docker engine and cli
        lazydocker

        # containers orcestration
        kubectl
        lens # k8s IDE
        kubernetes-helm
        minikube # local k8s like cluster
        azure-cli

        # virtual machines
        virtualbox # needed by minikube
      ];
  };
}
