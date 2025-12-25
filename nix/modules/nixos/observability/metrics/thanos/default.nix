{ pkgs, namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.observability.metrics.thanos;
  prometheus_config = config.services.prometheus;
  minio_config = config.${namespace}.storage.minio;

  writeYaml = (pkgs.formats.yaml { }).generate;

  # networking
  http_port = {
    sidecar = 10901;
    query-frontend = 10902;
    query = 10903;
    store = 10904;
    compact = 10905;
    receive = 10906;
  };
  grpc_port = {
    sidecar = 11901;
    store = 11902;
    query = 11903;
    query-frontend = 11904;
    receive = 11905;
    receive-remote-write = cfg.remote_write_port;
  };

  # bucket storage
  objectstore_config = {
    type = "S3";
    config = {
      bucket = "thanos";
      endpoint = schemaless_local_endpoint_on_port minio_config.port;
      access_key = minio_config.accessKey;
      secret_key = minio_config.secretKey;
      insecure = true;
    };
  };
  logging_config = {
    format = "json";
    level = "info";
  };
  tracing_config = service_short_name:
    let
      service_name = "thanos-${service_short_name}";
    in
    {
      type = "OTLP";
      config = {
        client_type = "grpc";
        endpoint = schemaless_local_endpoint_on_port cfg.otel_traces_grpc_port;
        inherit service_name;
        insecure = true;
      };
    };
in
{
  options.${namespace}.observability.metrics.thanos = with types; {
    enable = mkBoolOpt false "Whether or not to enable thanos metrics storage.";
    otel_traces_grpc_port = mkOption { type = types.int; description = "OpenTelemetry receiver port for the otlp-grpc protocol"; };
    remote_write_port = mkIntOpt 11908 "Prometheus remote-write endpoint port";
  };

  config = mkIf cfg.enable {
    # create S3 bucket for metrics
    ${namespace}.storage.minio = {
      enable = true;
      bucketNames = [ objectstore_config.config.bucket ];
    };


    # tell prometheus to save data in tsdb only for 2 hours
    services.prometheus = {
      extraFlags = [
        "--storage.tsdb.min-block-duration=2h"
        "--storage.tsdb.max-block-duration=2h"
      ];
      enableAgentMode = true;
      scrapeConfigs = [
        {
          job_name = "thanos";
          static_configs = [{
            targets = [
              (schemaless_local_endpoint_on_port http_port.sidecar)
              (schemaless_local_endpoint_on_port http_port.receive)
              (schemaless_local_endpoint_on_port http_port.compact)
              (schemaless_local_endpoint_on_port http_port.store)
              (schemaless_local_endpoint_on_port http_port.query)
              (schemaless_local_endpoint_on_port http_port.query-frontend)
            ];
          }];
        }
      ];
    };

    # thanos components
    services.thanos = {
      sidecar = {
        enable = prometheus_config.enable;
        prometheus.url = http_local_endpoint_on_port prometheus_config.port;
        http-address = broadcast_listen_on_port http_port.sidecar;
        grpc-address = broadcast_listen_on_port grpc_port.sidecar;
        objstore.config = objectstore_config;
        tracing.config = tracing_config "sidecar";
        log = logging_config;
      };

      receive = {
        enable = true;
        http-address = broadcast_listen_on_port http_port.receive;
        grpc-address = broadcast_listen_on_port grpc_port.receive;
        remote-write.address = broadcast_listen_on_port grpc_port.receive-remote-write;
        objstore.config = objectstore_config;
        tracing.config = tracing_config "receive";
        log = logging_config;
        labels = {
          "host" = config.networking.hostName;
          "receive" = "true";
        };
        arguments = [
          "--grpc-address=${broadcast_listen_on_port grpc_port.receive}"
          "--http-address=${broadcast_listen_on_port http_port.receive}"
          ''  --label=host=\"${config.networking.hostName}\"   ''
          ''  --label=receive=\"true\"                         ''
          "--objstore.config-file=${toString(writeYaml "objstore-config.yaml" objectstore_config)}"
          "--remote-write.address=${broadcast_listen_on_port grpc_port.receive-remote-write}"
          "--tsdb.path=/var/lib/thanos-receive"
          "--tracing.config-file=${toString(writeYaml "objstore-config.yaml" (tracing_config "receive"))}"
          "--tsdb.max-exemplars=9999"
        ];
      };

      compact = {
        enable = true;
        http-address = broadcast_listen_on_port http_port.compact;
        objstore.config = objectstore_config;
        tracing.config = tracing_config "compact";
        log = logging_config;
        retention = {
          resolution-raw = "7d";
          resolution-5m = "14d";
          resolution-1h = "1y";
        };
      };

      store = {
        enable = true;
        http-address = broadcast_listen_on_port http_port.store;
        grpc-address = broadcast_listen_on_port grpc_port.store;
        objstore.config = objectstore_config;
        tracing.config = tracing_config "store";
        log = logging_config;
      };

      query = {
        enable = true;
        http-address = broadcast_listen_on_port http_port.query;
        grpc-address = broadcast_listen_on_port grpc_port.query;
        tracing.config = tracing_config "query";
        log = logging_config;
        endpoints = [
          (schemaless_local_endpoint_on_port grpc_port.sidecar)
          (schemaless_local_endpoint_on_port grpc_port.store)
          (schemaless_local_endpoint_on_port grpc_port.receive)
        ];
      };

      query-frontend = {
        enable = true;
        http-address = broadcast_listen_on_port http_port.query-frontend;
        query-frontend.downstream-url = http_local_endpoint_on_port http_port.query;
        tracing.config = tracing_config "query-frontend";
        log = logging_config;
      };
    };

    services.grafana.provision.datasources.settings.datasources = [
      {
        name = "Thanos";
        type = "prometheus";
        uid = "thanos";
        access = "proxy";
        orgId = 1;
        url = http_local_endpoint_on_port http_port.query-frontend;
        basicAuth = false;
        isDefault = false;
        version = 1;
        editable = true;
        jsonData = {
          httpMethod = "GET";
          timeInterval = config.services.prometheus.globalConfig.scrape_interval;
          prometheusType = "Thanos";
          prometheusVersion = pkgs.thanos.version;
          exemplarTraceIdDestinations = [
            {
              datasourceUid = "tempo";
              name = "traceID"; # the name of metric label that would lead to the trace id.
            }
          ];
        };
      }
    ];
  };
} 
