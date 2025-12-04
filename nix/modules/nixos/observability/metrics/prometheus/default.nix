{ pkgs, namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.observability.metrics.prometheus;
in
{
  options.${namespace}.observability.metrics.prometheus = with types; {
    enable = mkBoolOpt false "Whether or not to enable promteheus metrics.";
    otel_traces_grpc_port = mkOption { type = types.int; description = "OpenTelemetry receiver port for the otlp-grpc protocol"; };
  };

  config = mkIf cfg.enable {
    services.prometheus = {
      enable = true;
      port = 9090; # default port
      globalConfig = {
        scrape_interval = "30s";
        external_labels = {
          "host" = config.networking.hostName;
        };
      };
      extraFlags = [
        "--enable-feature=exemplar-storage" # enable examplars
      ];

      # # enable node exporter and scrape it
      # exporters = {
      #   node = {
      #     enable = true;
      #     port = 9100;
      #     enabledCollectors = [ "tcpstat" "perf" "ethtool" "systemd" "cpu" "diskstats" "filesystem" "meminfo" "os" "time" ];
      #   };
      #   systemd = {
      #     enable = true;
      #     port = 9558;
      #     extraFlags = [
      #       "--systemd.collector.enable-restart-count"
      #     ];
      #   };
      # };
      #
      # scrapeConfigs = [
      #   {
      #     job_name = "exporters";
      #     static_configs = [{
      #       targets = [
      #         "localhost:${toString config.services.prometheus.exporters.node.port}"
      #         "localhost:${toString config.services.prometheus.exporters.systemd.port}"
      #       ];
      #     }];
      #   }
      # ];
    };
  };
}
 
