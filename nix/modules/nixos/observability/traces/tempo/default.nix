{ namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.observability.traces.tempo;
  minio_config = config.${namespace}.storage.minio;
  tempo_bucket_name = "tempo";
  # FIX: use as variable
  metrics_remote_write_endpoint = (http_local_endpoint_on_port 11908) + "/api/v1/receive";
  http_listen_port = 3200;

in
{
  options.${namespace}.observability.traces.tempo = with types; {
    enable = mkBoolOpt false "Whether or not to enable tempo traces storage.";
    otel_traces_grpc_port = mkOption { type = types.int; description = "tempo's OpenTelemetry collector otlp-grpc port"; };
  };

  config = mkIf cfg.enable {
    # create S3 bucket for traces
    ${namespace}.storage.minio = {
      enable = true;
      bucketNames = [ tempo_bucket_name ];
    };

    # scrape tempo metrics using prometheus
    services.prometheus = {
      scrapeConfigs = [
        {
          job_name = "tempo";
          static_configs = [{
            targets = [
              (schemaless_local_endpoint_on_port http_listen_port)
            ];
          }];
        }
      ];
    };

    # HACK: elevate tempo service permision to root
    systemd.services.tempo.serviceConfig.User = "root";
    services.tempo = {
      enable = true;
      settings = {
        server.http_listen_port = http_listen_port;
        # server.grpc_listen_address = cfg.otel_traces_grpc_port;
        # otel collector configuration
        distributor.receivers.otlp.protocols.grpc.endpoint = broadcast_listen_on_port cfg.otel_traces_grpc_port;
        # s3 browser configuration
        storage.trace = {
          backend = "s3";
          s3 = {
            endpoint = schemaless_local_endpoint_on_port minio_config.port;
            bucket = tempo_bucket_name;
            forcepathstyle = false;
            enable_dual_stack = false;
            access_key = minio_config.accessKey;
            secret_key = minio_config.secretKey;
            insecure = true;
          };
          wal.path = "/var/lib/tempo/wal";
          local.path = "/var/lib/tempo/blocks";
        };
        # metric generator
        overrides.defaults.metrics_generator.processors = [ "service-graphs" "local-blocks" ];
        metrics_generator = {
          storage = {
            path = "/var/lib/tempo/generator/wal";
            remote_write = [
              {
                url = metrics_remote_write_endpoint;
                send_exemplars = true;
                metadata_config.send = true;
              }
            ];
          };
          traces_storage.path = "/var/lib/tempo/generator/traces";
          registry.external_labels = {
            source = "tempo";
          };
        };
        # overrides.defaults.metrics_generator.processors = [ "service-grapths" "span-metrics" ];
        compactor.compaction.block_retention = "48h"; # total trace retention
        # send metrics to thanos 
        # metaMonitoring = {
        #   serviceMonitor.enabled = true;
        #   grafanaAgent = {
        #     enable = true;
        #     metrics.remote.url = metrics_remote_write_endpoint;
        #   };
        # };
      };
    };
  };
} 
