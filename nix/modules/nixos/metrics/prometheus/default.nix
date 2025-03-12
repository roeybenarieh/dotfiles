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
      globalConfig.scrape_interval = "15s"; # "1m"

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
  };
}
 
