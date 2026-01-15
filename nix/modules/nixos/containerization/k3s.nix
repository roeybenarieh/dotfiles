{ namespace, lib, config, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.containerization.k3s;
in
{
  options.${namespace}.containerization.k3s = with types; {
    enable = mkBoolOpt false "Whether or not to enable k3s.";
  };

  config = mkIf cfg.enable {
    # kubeconfig at: /etc/rancher/k3s/k3s.yaml
    services.k3s = {
      enable = true;
      role = "server";
      extraFlags = toString [
        "--disable traefik" # disable default ingress
        "--write-kubeconfig-mode 660" # change kubeconfig permissions
        "--write-kubeconfig-group k3s" # change kubeconfig group

        # experimental flags
        "--docker"
      ];
    };
  };
}
