{ pkgs, inputs, ... }@firefox-attrs:

{
  programs.firefox = {
    enable = true;
    package = pkgs.firefox;

    # Check about:policies#documentation for options.
    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
        EmailTracking = true;
      };
    };

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
