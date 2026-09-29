{ namespace, lib, config, pkgs, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktop.hyprland.voxtype;
  lua = lib.generators.mkLuaInline;
  voxtype = lib.getExe config.services.voxtype.package;
in
{
  options.${namespace}.desktop.hyprland.voxtype = {
    enable = mkBoolOpt false "Enable Voxtype: offline, CPU-only Parakeet speech-to-text dictation for Hyprland.";
    shortcut = mkstrOpt "SUPER + ALT + D" "Hyprland push-to-talk binding (hl.bind MODS + KEY syntax).";
  };

  config = mkIf cfg.enable {
    services.voxtype = {
      enable = true;
      # Enable ONNX engines for the CPU-optimized Parakeet INT8 model.
      package = pkgs.voxtype.override { onnxSupport = true; };
      loadModels = [ config.services.voxtype.settings.parakeet.model ];
      settings = {
        engine = "parakeet";
        state_file = "auto";
        hotkey.enabled = false; # Compositor bindings avoid raw input-device access.
        audio.pause_media = true;
        parakeet = {
          model = "parakeet-tdt-0.6b-v3-int8";
          model_type = "tdt";
          on_demand_loading = true;
        };
        output = {
          mode = "type";
          fallback_to_clipboard = true;
          notification = {
            on_recording_start = false;
            on_recording_stop = false;
            on_transcription = false;
          };
        };
      };
    };

    wayland.windowManager.hyprland.settings.bind = [
      { _args = [ cfg.shortcut (lua ''hl.dsp.exec_cmd("${voxtype} record start")'') ]; }
      { _args = [ cfg.shortcut (lua ''hl.dsp.exec_cmd("${voxtype} record stop")'') { release = true; } ]; }
    ];
  };
}
