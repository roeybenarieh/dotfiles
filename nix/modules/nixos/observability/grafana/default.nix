{ pkgs, namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.observability.grafana;
  # onlyIf = cond: elems: if cond then elems else [ ];
in
{
  options.${namespace}.observability.grafana = with types; {
    enable = mkBoolOpt false "Whether or not to enable grafana.";
  };

  config = mkIf cfg.enable {
    services.grafana = {
      enable = true;
      # for the whole list: http://localhost:3000/admin/settings
      settings = {
        # "" = {
        # instance_name = "home-computer";
        # somthing = "else";
        # };
        "analytics" = {
          instance_name = "home-computer";
          somthing = "else";
        };
      };
      provision = {
        enable = true;
        datasources.settings = {
          apiVersion = 1;
          # NOTE: when changing datasource you might need to run 'sudo rm -rf /var/lib/grafana'
          datasources = [
            (
              mkIf config.services.thanos.query-frontend.enable {
                name = "Thanos";
                type = "prometheus";
                uid = "thanos";
                access = "proxy";
                orgId = 1;
                # FIX: change this to use variable
                url = http_local_endpoint_on_port 10902;
                basicAuth = false;
                isDefault = false;
                version = 1;
                editable = true;
                jsonData = {
                  httpMethod = "GET";
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
            )
            # FIX: alot
            {
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
                httpMethod = "GET";
                serviceMap = {
                  # FIX: use thanos
                  datasourceUid = "thanos";
                };
              };
            }
          ];
        };
      };
    };

  };
} 
