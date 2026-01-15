{ pkgs, namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.audio;
in
{
  options.${namespace}.audio = with types; {
    enable = mkBoolOpt false "Whether or not to enable audio handling.";
  };

  config = mkIf cfg.enable {
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      # FIX: this doesn't work, I need it to not consider HDMI audio unless explicitly selected
      wireplumber = {
        enable = true;
        extraConfig = mkMerge [
          {
            "60-hdmi-lowprio" = {
              "monitor.alsa.rules" = singleton {
                matches = singleton {
                  "api.alsa.path" = "hdmi:.*";
                };

                actions.update-props = {
                  "node.name" = "Low Priority HDMI";
                  "node.nick" = "Low Priority HDMI";
                  "node.description" = "Low Priority HDMI";
                  "priority.session" = 100;
                  "node.pause-on-idle" = true;
                };
              };
            };
          }
        ];
      };
      # If you want to use JACK applications, uncomment this
      #jack.enable = true;

      # use the example session manager (no others are packaged yet so this is enabled by default,
      # no need to redefine it in your config for now)
      #media-session.enable = true;
    };
    environment.systemPackages = with pkgs; [
      pavucontrol # pulseaudio GUI
    ];
  };
}
 
