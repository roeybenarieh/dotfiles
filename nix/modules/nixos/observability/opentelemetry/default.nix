{ pkgs, namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.observability.opentelemetry;
  frontend_port = 12345;
in
{
  options.${namespace}.observability.opentelemetry = with types; {
    enable = mkBoolOpt false "Whether or not to enable OpenTelemetry related products.";
    otelp_grpc_port = mkIntOpt 4317 "port to run the otelp grpc receiver";
  };

  config = mkIf cfg.enable {
    # add firefox bookmarks
    ${namespace}.observability.grafana.observability_firefox_bookmarks = [
      {
        name = "grafana alloy";
        keyword = "alloy";
        url = (http_local_endpoint_on_port frontend_port) + "/graph";
      }
    ];

    # give alloy service permissions to access log files
    systemd.services.alloy.serviceConfig = {
      DynamicUser = mkForce false;
      Group = "root";
    };

    services.alloy = {
      enable = true;
      configPath = pkgs.writeText "config.alloy" ''
        // ===============================
        //        RECEIVERS (OTLP)
        // ===============================
        otelcol.receiver.otlp "default" {
          grpc { endpoint = "0.0.0.0:${toString cfg.otelp_grpc_port}" }
          output {
            metrics = [otelcol.processor.batch.default.input]
            logs    = [otelcol.processor.batch.default.input]
            traces  = [otelcol.processor.batch.default.input]
          }
        }
        otelcol.processor.batch "default" {
          output {
            metrics = [otelcol.exporter.prometheus.default.input]
            logs    = [otelcol.exporter.loki.default.input]
            traces  = [otelcol.exporter.otlp.default.input]
          }
        }

        // ===============================
        //        EXPORTERS (OTLP)
        // ===============================
        otelcol.exporter.loki "default" {
          forward_to = [loki.write.loki_push.receiver]
        }
        otelcol.exporter.prometheus "default" {
          forward_to = [prometheus.remote_write.thanos.receiver]
        }


        // ================================
        //   FIND LOGS FROM JOURNAL
        // ==============================
        loki.relabel "journal" {
          forward_to = []

          rule {
            source_labels = ["__journal__systemd_unit"]
            target_label  = "unit"
          }
        }
        loki.source.journal "read"  {
          forward_to    = [loki.write.loki_push.receiver]
          relabel_rules = loki.relabel.journal.rules
          labels        = {component = "loki.source.journal"}
        }

        // ================================
        //            SEND DATA
        // ================================
        // Loki
        loki.write "loki_push" {
          endpoint {
            url = "http://localhost:3100/loki/api/v1/push"
          }
          external_labels = {
            host = "${config.networking.hostName}",
          }
        }
        // Prometheus
        prometheus.remote_write "thanos" {
          endpoint {
            url = "http://localhost:11908/api/v1/receive"
          }
        }
        // OTLP
        otelcol.exporter.otlp "default" {
          client {
            endpoint = "localhost:11907"
            tls {
              insecure = true
            }
          }
        }

        // ================================
        //   General
        // ================================
        livedebugging {
          enabled = true
        }
        logging {
          level="info"
          format="json"
        }
      '';
      extraFlags = [
        "--server.http.listen-addr=0.0.0.0:${toString frontend_port}"
        "--stability.level=experimental"
        "--disable-reporting"
      ];
    };
  };
}
