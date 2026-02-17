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
    # Configure keymap in X11
    # services.xserver.xkb = {
    #   layout = "us";
    #   variant = "";
    # };
    # HACK: instead of using the services.xserver.xkb configuration, sets the keyboard layouts via 'setxkbmap' cli
    # set hebrew and english keyboard layouts
    # set Alt+Shift and Winkey+Space as layouts togglers
    services.xserver.displayManager.setupCommands = ''
      ${getExe pkgs.setxkbmap} -layout "us,il" -option "grp:alt_shift_toggle,grp:win_space_toggle"
    '';

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
 
