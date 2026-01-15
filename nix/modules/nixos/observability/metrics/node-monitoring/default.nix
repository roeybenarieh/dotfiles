{ namespace, lib, config, inputs, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.observability.metrics.scraping;
  nodeExporterPort = 9100;
  systemdExporterPort = 9558;
in
{
  options.${namespace}.observability.metrics.scraping = with types; {
    node.enable = mkBoolOpt false "Whether or not to enable node monitoring metrics.";
    systemd.enable = mkBoolOpt false "Whether or not to enable systemd monitoring metrics.";
  };

  config = {
    services.prometheus = {

      # enable exporters
      exporters = {
        node = {
          enable = cfg.node.enable;
          port = nodeExporterPort;
          enabledCollectors = [ "tcpstat" "perf" "ethtool" "systemd" "processes" "cpu" "diskstats" "filesystem" "meminfo" "os" "time" ];
        };
        systemd = {
          enable = cfg.systemd.enable;
          port = systemdExporterPort;
          extraFlags = [
            "--systemd.collector.enable-restart-count"
          ];
        };
      };

      # scrape exporters
      scrapeConfigs = [
        {
          job_name = "exporters";
          static_configs = [{
            targets = [
              (mkIf cfg.node.enable (schemaless_local_endpoint_on_port nodeExporterPort))
              (mkIf cfg.systemd.enable (schemaless_local_endpoint_on_port systemdExporterPort))
            ];
          }];
        }
      ];
    };
    services.grafana.provision.dashboards.settings.providers = [
      {
        name = "node exporter dashboard";
        type = "file";
        allowUiUpdates = false;
        options.path = "${inputs.grafana-dashboards}/dashboards/node-exporter-full.json";
      }
      {
        name = "thanos overview dashboard";
        type = "file";
        allowUiUpdates = false;
        options.path = "${inputs.grafana-dashboards}/dashboards/thanos-thanos-overview.json";
      }
    ];
  };
}
 
