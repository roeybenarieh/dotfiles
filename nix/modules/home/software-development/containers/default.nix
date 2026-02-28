{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.software-development.containers;
  gcloud = pkgs.google-cloud-sdk.withExtraComponents [ pkgs.google-cloud-sdk.components.gke-gcloud-auth-plugin ];
in
{
  options.${namespace}.software-development.containers = with types; {
    enable = mkBoolOpt false "Whether or not to enable containers related tools.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs;
      [
        # containers
        # docker # docker engine and cli
        lazydocker

        # containers orcestration
        kubectl
        lens # k8s IDE
        kubernetes-helm

        # TODO: orgenize everything to a Development folder(both in NixOS and in home-manager)
        # put bookmarks for developments related websites
        # cloud platforms
        gcloud
      ];
  };
}
