{ namespace, lib, config, pkgs, ... }@firefox-attrs:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.browser;
  # Desktop file id installed by each browser's Home Manager module (not always
  # the same as the option name, e.g. chromium installs "chromium-browser.desktop").
  browser_desktop_ids = {
    chromium = "chromium-browser.desktop";
    firefox = "firefox.desktop";
  };
  default_browser_desktop = browser_desktop_ids.${cfg.default_browser};
in
{
  options.${namespace}.browser = with types; {
    default_browser = mkOpt (nullOr (enum (attrNames browser_desktop_ids))) null "set the default browser used";
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
