{ pkgs, namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.metrics.prometheus;
in
{
  options.${namespace}.metrics.prometheus = with types; {
    enable = mkBoolOpt false "Whether or not to enable promteheus metrics.";
  };

  config = mkIf cfg.enable {
    services.prometheus = {
      enable = true;
      port = 9090; # default port
      globalConfig.scrape_interval = "15s";

      # enable node exporter and scrape it
      exporters = {
        node = {
          enable = true;
          port = 9100;
          enabledCollectors = [ "tcpstat" "perf" "ethtool" "systemd" "cpu" "diskstats" "filesystem" "meminfo" "os" "time" ];
        };
        systemd = {
          enable = true;
          port = 9558;
          extraFlags = [
            "--systemd.collector.enable-restart-count"
          ];
        };
      };

      scrapeConfigs = [
        {
          job_name = "exporters";
          static_configs = [{
            targets = [
              "localhost:${toString config.services.prometheus.exporters.node.port}"
              "localhost:${toString config.services.prometheus.exporters.systemd.port}"
            ];
          }];
        }
      ];
    };
  };
}
 
