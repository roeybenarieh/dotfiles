{ namespace, lib, config, pkgs, ... }@firefox-attrs:
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
      package = pkgs.firefox.overrideAttrs (old: {
        # MOZ_USE_XINPUT2=1 allow more smooth (pixel-level) scroll and zoom
        buildCommand = old.buildCommand + ''
          mv $out/bin/firefox $out/bin/firefox-no-xinput2
          makeWrapper $out/bin/firefox-no-xinput2 $out/bin/firefox --set-default MOZ_USE_XINPUT2 1
        '';
      });

      # Check about:policies#documentation for options.
      policies = {
        DisableTelemetry = true;
        DisableFirefoxStudies = true;
        DisplayBookmarksToolbar = "newtab"; # display bookmarks only on new tab
        EnableTrackingProtection = {
          Value = true;
          Locked = true;
          Cryptomining = true;
          Fingerprinting = true;
          EmailTracking = true;
        };
      };

      profiles.default = {
        isDefault = true; # set as the default profile
        settings = {
          # for more information visit in firefox browser:
          # about:config
          # or 
          # https://mozilla.github.io/policy-templates/#searchengines--add

          # disable transltation for hebrew and english
          "browser.translations.neverTranslateLanguages" = "en,he";

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

          # smooth scrolling
          "general.smoothScroll.msdPhysics.enabled" = true;
          "gfx.x11-egl.force-enabled" = true;
          "layers.acceleration.force-enabled" = true;

          # Disables playback of DRM-controlled HTML5 content
          # if enabled, automatically downloads the Widevine Content Decryption Module
          # provided by Google Inc. Details
          # (https://support.mozilla.org/en-US/kb/enable-drm#w_opt-out-of-cdm-playback-uninstall-cdms-and-stop-all-cdm-downloads)
          # used by websites like Spotify to play audio
          "media.eme.enabled" = true;
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
          default = "google";
          force = true; # force replay the existing search configuraiton
          engines = import ./search_engines.nix firefox-attrs;
        };
        bookmarks = {
          force = true;
          settings = import ./bookmarks.nix firefox-attrs;
        };
      };
      nativeMessagingHosts = with pkgs; [
        vdhcoapp
      ];
    };
  };
}
