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
          prune = true; # remove old datasources
          datasources = [
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
