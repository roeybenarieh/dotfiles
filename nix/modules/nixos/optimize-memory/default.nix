{ pkgs, namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.optimizeMemory;
in
{
  options.${namespace}.optimizeMemory = with types; {
    enable = mkBoolOpt false "Whether or not to enable features for optimizing memory.";
  };

  config = mkIf cfg.enable {
    # Chromium memory savings:
    # Chromium 153's Maximum Memory Saver still waits two hours. Auto Tab
    # Discard uses native discarding on a shorter timer, without closing tabs.
    # https://github.com/rNeomy/auto-tab-discard/blob/master/v3/schema.json
    #
    # Native Memory Saver must stay OFF: it eagerly freezes background tabs,
    # and waking a frozen renderer to inject ATD's probe script resets
    # performance.timing.domLoading to "now". ATD's age check
    # (meta.js: time = window.lastVisit || performance.timing.domLoading)
    # then always reads the tab as freshly loaded, so it never crosses the
    # idle threshold and ATD can never discard it. ATD must be the only
    # tab-sleep mechanism running.
    programs.chromium.extraOpts = {
      "HighEfficiencyModeEnabled" = false;
      "NetworkPredictionOptions" = 2; # Disable speculative preloading and preconnections.
      "BackgroundModeEnabled" = false; # Release background apps after the last window closes.

      # ExtensionSettings (not the legacy ExtensionInstallForcelist) actively
      # re-enforces force_installed on every policy refresh, re-enabling the
      # extension even if it was previously left disabled.
      "ExtensionSettings"."jhnleheckmknfcgijgkadoemagpecfol" = {
        installation_mode = "force_installed";
        update_url = "https://clients2.google.com/service/update2/crx";
      };

      # Linux extension policies go directly under the extension ID (no "policy" key).
      # ATD uses managed storage as defaults; its locally saved UI settings win.
      "3rdparty".extensions."jhnleheckmknfcgijgkadoemagpecfol" = {
        mode = "time-based";
        period = 300; # Seconds inactive; checked roughly every period / 3.
        number = 0; # No minimum background-tab count before discarding.
        audio = true;
        pinned = true;
        form = true; # Best-effort detection; pin/exclude important editors and calls.
        "notification.permission" = true;
        online = true; # Keep loaded pages available while offline.
        battery = false; # Also discard when plugged in.
        "memory-enabled" = false; # Heap-size forcing bypasses form/media protections.
        favicon = true; # Gray out + dot-overlay the favicon of discarded tabs.
        # Force-discards already-open, non-active unpinned tabs the moment
        # Chromium starts (bypassing the normal age/period check entirely),
        # so idle tabs restored from session restore get freed immediately
        # instead of waiting on the periodic check.
        "startup-unpinned" = true;
        "startup-pinned" = false;
        "release-next-tab" = false; # Do not proactively reload a neighbouring tab.
        faqs = false;
      };
    };
  };
}
