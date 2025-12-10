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
  };

  config = mkIf cfg.enable {
    # give alloy service permissions to access log files
    systemd.services.alloy.serviceConfig = {
      DynamicUser = mkForce false;
      Group = "root";
    };

    services.alloy = {
      enable = true;
      configPath = pkgs.writeText "config.alloy" ''
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
          forward_to    = [loki.process.logs.receiver]
          relabel_rules = loki.relabel.journal.rules
          labels        = {component = "loki.source.journal"}
        }

        // ================================
        //   PROCESS LOGS - add 'host' label
        // ================================
        loki.process "logs" {
          stage.labels {
            values = {
              host = "${config.networking.hostName}",
            }
          }
          forward_to = [loki.write.loki_push.receiver]
        }

        // ================================
        //   SEND TO LOKI
        // ================================
        loki.write "loki_push" {
          endpoint {
            url = "http://localhost:3100/loki/api/v1/push"
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
