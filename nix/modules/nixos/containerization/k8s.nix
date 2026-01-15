{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.containerization.k8s;
  kubeMasterHostname = "api.kube";
  kubeMasterIP = "127.0.0.1";
  kubeMasterAPIServerPort = 6443;
in
{
  options.${namespace}.containerization.k8s = with types; {
    enable = mkBoolOpt false "Whether or not to enable k8s.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      kubectl
    ];
    # example command: sudo kubectl --kubeconfig "/etc/kubernetes/config" --namespace kube-system get pods
    networking.extraHosts = "${kubeMasterIP} ${kubeMasterHostname}";
    services.kubernetes = {
      easyCerts = true;
      # addons.dashboard.enable = true;
      roles = [ "master" "node" ];
      masterAddress = kubeMasterHostname;
      apiserverAddress = "https://${kubeMasterHostname}:${toString kubeMasterAPIServerPort}";
      flannel = disabled;
      apiserver = {
        securePort = kubeMasterAPIServerPort;
        advertiseAddress = "0.0.0.0";
      };
      addons.dns = enabled;
      pki = {
        enable = true;
        etcClusterAdminKubeconfig = "kubernetes/config"; # kubeconfig found in /etc/kubernetes/config
      };
    };
    systemd.services.kubelet.serviceConfig = {
      User = "kubernetes";
      Group = "root";
    };
  };
}
