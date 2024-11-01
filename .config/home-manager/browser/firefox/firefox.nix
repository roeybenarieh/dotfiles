{ pkgs, inputs, ... }:

{
  programs.firefox = {
    enable = true;
    package = pkgs.firefox;
    profiles.roey = {
      isDefault = true; # set as the default profile
      # policies = {
      #   DisableTelemetry = true;
      #   DisableFirefoxStudies = true;
      # };
      settings = {
        # this like has every setting: https://mozilla.github.io/policy-templates/#searchengines--add

        # "browser.startup.homepage" = "https://www.ecosia.org";
        "browser.startup.page" = "https://www.ecosia.org";
        "startup.homepage_welcome_url" = "https://www.ecosia.org";
        "dom.security.https_only_mode" = true;
        "extensions.autoDisableScopes" = 0; # automaticly enable every extension
      };
      # configure search engines
      extensions = with inputs.firefox-addons.packages."x86_64-linux"; [
        # TODO: auto enable the extensions
        vimium
        to-google-translate
        darkreader
        ublock-origin
        ecosia
        # video-downloadhelper
        # jsonview
      ];
      search = {
        default = "Ecosia";
        engines = {
          # force = true; # force replay the existing search configuraiton
          "Google".metaData.alias = "@g"; # builtin engines only support specifying one additional alias

          "Nix Packages" = {
            urls = [{
              template = "https://search.nixos.org/packages";
              params = [{ name = "type"; value = "packages"; } { name = "query"; value = "{searchTerms}"; }];
            }];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = [ "@np" "@nixpkgs" ];
          };

          "Source Graph" = {
            urls = [{
              template = "https://sourcegraph.com/search";
              params = [{ name = "q"; value = "{searchTerms}"; }];
            }];
            definedAliases = [ "@sg" "@sourcegraph" ];
          };

          "Ecosia" = {
            urls = [{
              template = "https://www.ecosia.org/search";
              iconurl = "https://www.ecosia.org/search/favicon.ico";
              params = [{ name = "method"; value = "index"; } { name = "q"; value = "{searchTerms}"; }];
            }];
          };

        };
      };
      bookmarks = import ./firefox_bookmarks.nix { };
    };
  };
}
