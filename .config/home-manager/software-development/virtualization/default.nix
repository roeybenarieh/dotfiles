{ config, pkgs, pkgs-stable, ... }:

{
  home.packages = with pkgs;
    [
      # containers
      docker
      lazydocker

      # containers orcestration
      kubectl
      ocm # openshift 'oc' cli
      lens # k8s IDE
    ] ++ [
      pkgs-stable.kubernetes-helm
      pkgs-stable.minikube # local k8s like cluster
      pkgs-stable.azure-cli

      # virtual machines
      pkgs-stable.virtualbox # local k8s like cluster
    ];
}
