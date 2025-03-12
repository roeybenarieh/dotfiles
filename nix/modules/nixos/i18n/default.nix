{ pkgs, namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.i18n;
in
{
  options.${namespace}.i18n = with types; {
    enable = mkBoolOpt false "Whether or not to enable internalization related configuration.";
  };

  config = mkIf cfg.enable {
    # Configure console keymap
    console.keyMap = "il";

    # Configure keymap in X11
    services.xserver.xkb = {
      layout = "us";
      variant = "";
    };

    # Set your time zone.
    time.timeZone = "Asia/Tel_Aviv";

    # Select internationalisation properties.
    # full list found in: https://sourceware.org/git/?p=glibc.git;a=blob;f=localedata/SUPPORTED

    i18n.extraLocaleSettings = {
      LC_ADDRESS = "en_IL";
      LC_IDENTIFICATION = "en_IL";
      LC_MEASUREMENT = "en_IL";
      LC_MONETARY = "en_IL";
      LC_NAME = "en_IL";
      LC_NUMERIC = "en_IL";
      LC_PAPER = "en_IL";
      LC_TELEPHONE = "en_IL";
      LC_TIME = "en_US.UTF-8";
    };
  };
}
 
