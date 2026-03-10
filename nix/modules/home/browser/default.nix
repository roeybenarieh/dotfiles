{ namespace, lib, config, pkgs, ... }@firefox-attrs:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.browser;
  default_browser_desktop = "${cfg.default_browser}.desktop";
in
{
  options.${namespace}.browser = with types; {
    default_browser = mkstrOpt null "set the default browser used";
  };

  config = mkIf (cfg.default_browser != null) {
    home.sessionVariables = {
      BROWSER = cfg.default_browser;
    };
    xdg.mimeApps = {
      enable = true;
      # to get mime type run: file -b --mime-type <file_name>
      defaultApplications = {
        "text/html" = default_browser_desktop;
        "application/pdf" = default_browser_desktop;
        "image/jpeg" = default_browser_desktop;
        "image/png" = default_browser_desktop;
        "image/gif" = default_browser_desktop;
        "x-scheme-handler/http" = default_browser_desktop;
        "x-scheme-handler/https" = default_browser_desktop;
        "x-scheme-handler/about" = default_browser_desktop;
        "x-scheme-handler/unknown" = default_browser_desktop;
      };
    };
  };
}
