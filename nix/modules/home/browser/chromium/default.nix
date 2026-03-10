{ namespace, lib, config, ... }:

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
      extensions = [
        "epcnnfbjfcgphgdmggkamkmgojdagdnn" # ublock
        "dbepggeogbaibhgnhhndojpepiihcmeb" # vimium
      ];
      commandLineArgs = [
        "--enable-features=TouchpadOverscrollHistoryNavigation" # use touchpad to navigate between pages
      ];
    };
  };
}
