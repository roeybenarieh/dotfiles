{ pkgs, inputs, ... }@firefox-attrs:

{
  programs.firefox = {
    enable = true;
    package = pkgs.firefox;
    profiles.roey = {
      isDefault = true; # set as the default profile
      settings = {
        # for more information visit in firefox browser:
        # about:config
        # or 
        # https://mozilla.github.io/policy-templates/#searchengines--add

        # restore the previous session on startup
        "browser.startup.page" = 3; # 3 means "Show my windows and tabs from last time"
        "browser.warnOnQuit" = false; # Disable warning on quit
        "browser.sessionstore.resume_from_crash" = true; # Resume from crash

        # find bar preferences(Ctrl+F)
        "findbar.entireword" = false;
        "findbar.highlightAll" = true;

        # download related
        "browser.download.lastDir" = "~/Downloads";
        "browser.download.panel.shown" = true;

        "dom.security.https_only_mode" = true;
        # automaticly enable every extension
        "extensions.autoDisableScopes" = 0;
        # Disable telemetry
        # https://wiki.mozilla.org/Platform/Features/Telemetry
        # https://wiki.mozilla.org/Privacy/Reviews/Telemetry
        # https://wiki.mozilla.org/Telemetry
        # https://www.mozilla.org/en-US/legal/privacy/firefox.html#telemetry
        # https://support.mozilla.org/t5/Firefox-crashes/Mozilla-Crash-Reporter/ta-p/1715
        # https://wiki.mozilla.org/Security/Reviews/Firefox6/ReviewNotes/telemetry
        # https://gecko.readthedocs.io/en/latest/browser/experiments/experiments/manifest.html
        # https://wiki.mozilla.org/Telemetry/Experiments
        # https://support.mozilla.org/en-US/questions/1197144
        # https://firefox-source-docs.mozilla.org/toolkit/components/telemetry/telemetry/internals/preferences.html#id1
        "toolkit.telemetry.enabled" = false;
        "toolkit.telemetry.unified" = false;
        "toolkit.telemetry.archive.enabled" = false;
        "experiments.supported" = false;
        "experiments.enabled" = false;
        "experiments.manifest.uri" = "";
        # Disable health reports (basically more telemetry)
        # https://support.mozilla.org/en-US/kb/firefox-health-report-understand-your-browser-perf
        # https://gecko.readthedocs.org/en/latest/toolkit/components/telemetry/telemetry/preferences.html
        "datareporting.healthreport.uploadEnabled" = false;
        "datareporting.healthreport.service.enabled" = false;
        "datareporting.policy.dataSubmissionEnabled" = false;
        "browser.urlbar.update2.engineAliasRefresh" = true;
      };
      # configure search engines
      extensions = with inputs.firefox-addons.packages."x86_64-linux"; [
        # TODO: auto enable the extensions
        vimium
        to-google-translate
        darkreader
        ublock-origin
        # ecosia
        # video-downloadhelper
        # jsonview
      ];
      search = {
        default = "Google";
        force = true; # force replay the existing search configuraiton
        engines = import ./search_engines.nix firefox-attrs;
      };
      bookmarks = import ./bookmarks.nix firefox-attrs;
    };
  };
}
