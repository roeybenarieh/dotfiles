{ namespace, lib, config, pkgs, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.browser.chromium;
in
{
  options.${namespace}.browser.chromium = with types; {
    enable = mkBoolOpt false "Whether or not to enable chromium.";
  };

  config = mkIf cfg.enable {
    programs.chromium = {
      enable = true;
      package = pkgs.chromium.override {
        enableWideVine = true; # allows playing DRM-protected content (like Netflix, Spotify, or Amazon Prime)
      };
      extensions = [
        "epcnnfbjfcgphgdmggkamkmgojdagdnn" # ublock
        "dbepggeogbaibhgnhhndojpepiihcmeb" # vimium
        "khncfooichmfjbepaaaebmommgaepoid" # Unhook - Remove YouTube Recommended & Shorts
      ];
      commandLineArgs = [
        "--enable-features=TouchpadOverscrollHistoryNavigation" # use touchpad to navigate between pages
        "--enable-background-mode" # keep process alive after last window closes, so preload is always ready
      ];
    };
  };
}
