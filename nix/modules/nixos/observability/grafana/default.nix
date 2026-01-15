{ namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.observability.grafana;
  http_port = 3000;
in
{
  options.${namespace}.observability.grafana = with types; {
    enable = mkBoolOpt false "Whether or not to enable grafana.";
    observability_firefox_bookmarks = lib.mkOption {
      type = lib.types.listOf types.anything;
      default = [ ];
    };
  };

  config = mkIf cfg.enable {

    # scrape grafana metrics using prometheus
    services.prometheus = {
      scrapeConfigs = [
        {
          job_name = "grafana";
          static_configs = [{
            targets = [
              (schemaless_local_endpoint_on_port http_port)
            ];
          }];
        }
      ];
    };
    # set firefox bookmarks
    snowfallorg.users.roey.home.config.programs.firefox.profiles.default.bookmarks.settings = [{
      name = "Something";
      toolbar = true;
      bookmarks = [
        {
          name = "observability";
          bookmarks = cfg.observability_firefox_bookmarks ++ [
            {
              name = "grafana";
              url = http_local_endpoint_on_port http_port;
            }
          ];
        }
      ];
    }];

    services.grafana = {
      enable = true;
      # for the whole list: http://localhost:3000/admin/settings
      settings = {
        # "" = {
        # instance_name = "home-computer";
        # somthing = "else";
        # };
        server.http_port = http_port;
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
          # datasources are configured by each product itself
        };
      };
    };
  };
} 
