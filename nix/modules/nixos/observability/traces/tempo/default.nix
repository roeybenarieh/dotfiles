{ pkgs, namespace, lib, config, ... }:

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
    # HACK: sleep until the minio service is on
    systemd.services.tempo.serviceConfig.ExecStartPre = "${pkgs.coreutils}/bin/sleep 10";

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
    # add tempo to Grafana datasources
    services.grafana.provision.datasources.settings.datasources = [
      {
        # https://grafana.com/docs/grafana/latest/datasources/tempo/configure-tempo-data-source/
        name = "Tempo";
        type = "tempo";
        access = "proxy";
        uid = "tempo";
        orgId = 1;
        url = "http://localhost:3200";
        basicAuth = false;
        isDefault = true;
        version = 1;
        editable = true;
        apiVersion = 1;
        jsonData = {
          # TODO:use variables insted of hard coded datasources ids.
          tracesToLogsV2.datasourceUid = "loki";
          tracesToMetrics.datasourceUid = "thanos";
          serviceMap.datasourceUid = "thanos";
          nodeGraph.enabled = true;
          streamingEnabled.search = true;
        };
      }
    ];

    services.tempo = {
      enable = true;
      settings = {
        server.http_listen_port = http_listen_port;
        # ddistributor configuration
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
          wal.path = "/tmp/tempo/wal";
          local.path = "/tmp/tempo/blocks";
        };
        # metric generator
        overrides.defaults.metrics_generator = {
          processors = [ "service-graphs" "span-metrics" "local-blocks" ];
          trace_id_label_name = "traceID";
        };
        metrics_generator = {
          storage = {
            path = "/tmp/tempo/generator/wal";
            remote_write = [
              {
                url = metrics_remote_write_endpoint;
                send_exemplars = true;
                metadata_config.send = true;
              }
            ];
          };
          traces_storage.path = "/tmp/tempo/generator/traces";
          registry.external_labels = {
            source = "tempo";
          };
        };
        compactor.compaction.block_retention = "48h"; # total trace retention
      };
    };
  };
} 
