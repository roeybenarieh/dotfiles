{ config, pkgs, pkgs-stable, ... }:

{
  home.packages = with pkgs; [
    # virtual machines
    virtualbox

    # containers
    docker
    lazydocker

    # containers orcestration
    kubectl
    ocm # openshift 'oc' cli
  ] ++ [ pkgs-stable.kubernetes-helm ];
}
