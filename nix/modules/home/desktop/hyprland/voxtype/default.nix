{ namespace, lib, config, pkgs, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktop.hyprland.voxtype;
  lua = lib.generators.mkLuaInline;
  voxtype = lib.getExe config.services.voxtype.package;
  microphone = pkgs.writeShellApplication {
    name = "voxtype-microphone";
    runtimeInputs = with pkgs; [ coreutils pulseaudio libnotify util-linux ];
    text = builtins.readFile ./microphone.sh;
  };
in
{
  options.${namespace}.desktop.hyprland.voxtype = {
    enable = mkBoolOpt false "Enable Voxtype: offline, CPU-only Parakeet speech-to-text dictation for Hyprland.";
    shortcut = mkstrOpt "SUPER + ALT + D" "Hyprland push-to-talk binding (hl.bind MODS + KEY syntax).";
  };

  config = mkIf cfg.enable {
    services.voxtype = {
      enable = true;
      # Voxtype launches hooks with `sh`, which its package wrapper omits.
      environment.PATH = lib.mkForce (lib.makeBinPath [ pkgs.bash pkgs.coreutils ]);
      # Enable ONNX engines for the CPU-optimized Parakeet INT8 model.
      package = pkgs.voxtype.override { onnxSupport = true; };
      loadModels = [ config.services.voxtype.settings.parakeet.model ];
      settings = {
        engine = "parakeet";
        state_file = "auto";
        hotkey.enabled = false; # Compositor bindings avoid raw input-device access.
        audio.pause_media = true;
        audio.max_duration_secs = 600; # Allow up to 10 minutes of dictation.
        parakeet = {
          model = "parakeet-tdt-0.6b-v3-int8";
          model_type = "tdt";
          on_demand_loading = true;
        };
        output = {
          # The hook runs after the recording state is written. Detach the
          # watcher so the daemon can process stop/cancel while it runs.
          pre_recording_command = "${lib.getExe microphone} ${toString config.services.voxtype.settings.audio.max_duration_secs} >/dev/null 2>&1 &";
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
