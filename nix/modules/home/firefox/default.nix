{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.firefox;
in
{
  options.${namespace}.firefox = with types; {
    enable = mkBoolOpt false "Whether or not to enable firefox.";
  };

  config = mkIf cfg.enable {
    home.sessionVariables = {
      BROWSER = "firefox";
    };
    # make firefox the default for opening things
    xdg.mimeApps = {
      enable = true;
      # to get mime type run: file -b --mime-type <file_name>
      defaultApplications = {
        "text/html" = "firefox.desktop";
        "application/pdf" = "firefox.desktop";
        "image/jpeg" = "firefox.desktop";
        "image/png" = "firefox.desktop";
        "image/gif" = "firefox.desktop";
        "x-scheme-handler/http" = "firefox.desktop";
        "x-scheme-handler/https" = "firefox.desktop";
        "x-scheme-handler/about" = "firefox.desktop";
        "x-scheme-handler/unknown" = "firefox.desktop";
      };
    };

    # the firefox configuration itself
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

          # automatic fill
          "extensions.formautofill.creditCards.enabled" = false; # dont auto fill credit cards

          # telemetry
          "toolkit.telemetry.server" = "data:,"; # change telemetry server
        };
        # configure search engines
        extensions = {
          force = true;
          # nur packages can be found at: https://nur.nix-community.org/repos/rycee
          packages = with pkgs.nur.repos.rycee.firefox-addons; [
            # TODO: auto enable the extensions
            vimium
            to-google-translate
            darkreader
            ublock-origin
            video-downloadhelper
            privacy-badger
          ];
          # FIX: every time I used video Downloadhelper, it changes the settings, and home manager gets error on rebuild
          # settings = {
          #   # Video DownloadHelper
          #   "{b9db16a4-6edc-47ec-a1f4-b86292ed211d}".settings = import ./extension_settings/video-downloadhelper.nix firefox-attrs;
          # };
        };
        search = {
          default = "Google";
          force = true; # force replay the existing search configuraiton
          engines = import ./search_engines.nix firefox-attrs;
        };
        bookmarks = import ./bookmarks.nix firefox-attrs;
      };
      nativeMessagingHosts = with pkgs; [
        vdhcoapp
      ];
    };
  };
}
