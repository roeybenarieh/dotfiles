{ config, ... }:

# taken from https://wiki.nixos.org/wiki/Prometheus
{
  services.prometheus = {
    enable = true;
    port = 9090; # default port
    globalConfig.scrape_interval = "15s"; # "1m"
    enableReload = true;

    # alert manager config
    alertmanager = {
      enable = true;
      port = 9093;
      configText = ''
        global:
          resolve_timeout: 5m

        route:
          receiver: 'default'

        receivers:
          - name: 'default'

        inhibit_rules:
          - source_match:
              severity: 'critical'
            target_match:
              severity: 'warning'
            equal: ['alertname', 'dev', 'instance']
      '';
    };

    # enable node exporter and scrape it
    exporters.node = {
      enable = true;
      port = 9000;
      enabledCollectors = [ "tcpstat" "perf" "ethtool" "systemd" "cpu" "diskstats" "filesystem" "meminfo" "os" "time" ];
    };
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [{
          targets = [ "localhost:${toString config.services.prometheus.exporters.node.port}" ];
        }];
      }
    ];
  };
}
