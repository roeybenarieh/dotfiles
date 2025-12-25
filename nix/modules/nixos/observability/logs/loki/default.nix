{ pkgs, namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.observability.logs.loki;
  minio_config = config.${namespace}.storage.minio;
  loki_bucket_name = "loki";
  frontend_port = 3100;
in
{
  options.${namespace}.observability.logs.loki = with types; {
    enable = mkBoolOpt false "Whether or not to enable tempo traces storage.";
  };

  config = mkIf cfg.enable {
    # create S3 bucket for traces
    ${namespace}.storage.minio = {
      enable = true;
      bucketNames = [ loki_bucket_name ];
    };
    # HACK: sleep until the minio service is on
    systemd.services.loki.serviceConfig.ExecStartPre = "${pkgs.coreutils}/bin/sleep 10";

    # scrape tempo metrics using prometheus
    services.prometheus = {
      scrapeConfigs = [
        {
          job_name = "loki";
          static_configs = [{
            targets = [
              (schemaless_local_endpoint_on_port frontend_port)
            ];
          }];
        }
      ];
    };


    services.loki = {
      enable = true;
      configuration = {
        auth_enabled = false;
        server.http_listen_port = frontend_port;
        ui.enabled = true;

        common = {
          storage.object_store.s3 = {
            bucket_name = loki_bucket_name;
            endpoint = schemaless_local_endpoint_on_port minio_config.port;
            insecure = true;
            inherit (minio_config) region;
            access_key_id = minio_config.accessKey;
            secret_access_key = minio_config.secretKey;
            trace.enabled = true;
          };
          path_prefix = "/tmp/loki";
        };
        # FIX: change this grpc listener port(and others) to alloy opentelemetry collector
        # FIX: scape localhost logs using alloy/fluentbit
        server.grpc_listen_port = 11909;
        storage_config.use_thanos_objstore = true; # use Thanos related go package for sending data to s3 bucke };
        compactor.compaction_interval = "5m";
        distributor.ring.kvstore.store = "inmemory";
        ingester = {
          lifecycler = {
            address = "127.0.0.1";
            ring = {
              kvstore = {
                store = "inmemory";
              };
              replication_factor = 1;
            };
          };
        };
      };
    };

    services.loki.configuration.schema_config = {
      configs = [
        {
          from = "2020-05-15";
          store = "tsdb";
          object_store = "s3";
          schema = "v13";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }
      ];
    };

    services.grafana.provision.datasources.settings.datasources = [
      {
        name = "Loki";
        type = "loki";
        access = "proxy";
        uid = "loki";
        orgId = 1;
        url = http_local_endpoint_on_port frontend_port;
        basicAuth = false;
        isDefault = false;
        editable = true;
      }
    ];
  };
}
