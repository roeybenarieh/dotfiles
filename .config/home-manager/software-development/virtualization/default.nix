{ config, pkgs, ... }:

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
      kubernetes-helm
      minikube # local k8s like cluster
      azure-cli

      # virtual machines
      virtualbox # local k8s like cluster
    ];
}
