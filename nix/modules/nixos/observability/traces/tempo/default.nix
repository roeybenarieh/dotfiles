{ pkgs, namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.observability.traces.tempo;
  s3compatible_config = config.${namespace}.storage.s3compatible;
  tempo_bucket_name = "tempo";
  metrics_remote_write_endpoint = (http_local_endpoint_on_port config.${namespace}.observability.metrics.thanos.remote_write_port) + "/api/v1/receive";
  http_listen_port = 3200;

in
{
  options.${namespace}.observability.traces.tempo = with types; {
    enable = mkBoolOpt false "Whether or not to enable tempo traces storage.";
    otel_traces_grpc_port = mkOption { type = types.int; description = "tempo's OpenTelemetry collector otlp-grpc port"; };
  };

  config = mkIf cfg.enable {
    # create S3 bucket for traces
    ${namespace}.storage.s3compatible = {
      enable = true;
      bucketNames = [ tempo_bucket_name ];
    };
    # HACK: sleep until the s3compatible service is on
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
        url = http_local_endpoint_on_port http_listen_port;
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
        # Grafana's streaming search (jsonData.streamingEnabled.search above) needs
        # gRPC-shaped responses; this streams them over http_listen_port instead of
        # requiring a separate gRPC connection, which the sandboxed/loopback-only
        # gRPC port isn't set up for Grafana to reach.
        stream_over_http_enabled = true;
        server = {
          inherit http_listen_port;
          log_format = "json";
        };
        # ddistributor configuration
        distributor.receivers.otlp.protocols.grpc.endpoint = broadcast_listen_on_port cfg.otel_traces_grpc_port;
        # s3 browser configuration
        storage.trace = {
          backend = "s3";
          s3 = {
            endpoint = schemaless_local_endpoint_on_port s3compatible_config.port;
            bucket = tempo_bucket_name;
            forcepathstyle = false;
            enable_dual_stack = false;
            access_key = s3compatible_key_id s3compatible_config.accessKey;
            secret_key = s3compatible_key_secret s3compatible_config.secretKey;
            insecure = true;
          };
          wal.path = "/tmp/tempo/wal";
          local.path = "/tmp/tempo/blocks";
        };
        # metric generator
        # NOTE: Tempo 3.0 removed the "local-blocks" metrics-generator processor
        # (and its local_blocks/traces_storage settings) along with the ingester
        # and compactor components - see https://grafana.com/docs/tempo/latest/set-up-for-tracing/setup-tempo/migrate-to-3/
        overrides.defaults.metrics_generator = {
          processors = [ "service-graphs" "span-metrics" ];
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
          registry.external_labels = {
            source = "tempo";
          };
        };
        # compactor was replaced by backend_scheduler/backend_worker in Tempo 3.0;
        # in monolithic (target=all) mode the scheduler runs in-process, no separate worker needed.
        backend_scheduler = {
          local_work_path = "/tmp/tempo/backend-scheduler";
          provider.compaction.compaction.block_retention = "720h"; # 30 days
        };
        # live-store replaced the ingester in Tempo 3.0; its defaults live under
        # /var/tempo, which is read-only under the tempo.service sandbox (ProtectSystem=full),
        # so point it at the same writable /tmp/tempo prefix used above.
        live_store = {
          wal.path = "/tmp/tempo/live-store/traces";
          shutdown_marker_dir = "/tmp/tempo/live-store/shutdown-marker";
        };
      };
    };
  };
} 
