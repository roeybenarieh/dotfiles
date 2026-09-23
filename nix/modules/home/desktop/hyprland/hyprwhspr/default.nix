{ namespace, lib, config, pkgs, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktop.hyprland.hyprwhspr;
  lua = lib.generators.mkLuaInline;

  # hyprwhspr has no upstream Nix packaging and isn't in nixpkgs, so it's built
  # here from source. Pinned to a release tag for reproducibility; bump both
  # rev and hash together (`nix run nixpkgs#nix-prefetch-github -- goodroot
  # hyprwhspr --rev <tag>` prints both).
  hyprwhsprSrc = pkgs.fetchFromGitHub {
    owner = "goodroot";
    repo = "hyprwhspr";
    rev = "f1d88cb12e5e2faf1e111054626bf9c571905d27"; # v1.45.2
    hash = "sha256-CSdmvNc1oenR9PxxaUMcHj3FnqHXWmNTnO8Ll9YG/nc=";
  };

  # Only lib/ (the Python application) and share/ (sounds + the config JSON
  # schema) are needed at runtime — docs/tests/scripts/contrib/website are
  # upstream's own bootstrap/AUR/build tooling and aren't used here.
  #
  # Also ships a sitecustomize.py (see below) that forces onnxruntime onto
  # CPUExecutionProvider only.
  hyprwhsprUnwrapped = pkgs.runCommand "hyprwhspr-unwrapped" { } ''
    mkdir -p "$out/sitecustomize"
    cp -r "${hyprwhsprSrc}/lib" "${hyprwhsprSrc}/share" "$out/"
    cp ${./sitecustomize.py} "$out/sitecustomize/sitecustomize.py"
  '';

  # requirements.txt + requirements-onnx-asr.txt (the backend this module
  # pins: Parakeet TDT v3 via onnx-asr, CPU-only, int8-quantized — no GPU,
  # low RAM/CPU footprint) plus, optionally, requirements-visualizer.txt for
  # the mic-osd overlay. All present in nixpkgs, so no pip/venv step at
  # runtime is needed (unlike upstream's own self-managed-venv installer).
  hyprwhsprPython = pkgs.python3.withPackages (
    ps:
    with ps;
    [
      sounddevice
      numpy
      soxr
      soundfile
      evdev
      pyperclip
      pyudev
      pulsectl
      rich
      jsonschema
      requests
      onnx-asr
      huggingface-hub
      dbus-python # MPRIS media-player pause/resume during recording (audio_ducking_mode = "pause")
    ]
    ++ optionals cfg.micOsd.enable [ pygobject3 pycairo ]
  );

  # mic-osd draws its overlay with GTK4 + gtk4-layer-shell via GObject
  # introspection; pygobject3 alone doesn't ship their typelibs.
  hyprwhsprGiTypelibPath = lib.makeSearchPath "lib/girepository-1.0" (
    with pkgs;
    [ gtk4 gtk4-layer-shell glib gdk-pixbuf pango harfbuzz graphene ]
  );

  hyprwhspr = pkgs.writeShellApplication {
    name = "hyprwhspr";
    runtimeInputs = with pkgs; [
      hyprwhsprPython
      ydotool
      wtype
      wl-clipboard
      pulseaudio # pactl, for source/sink control
      libnotify
      # hyprctl, for focused-window detection — reuse the already-configured
      # Hyprland package (already part of this profile's closure as the
      # window manager itself) rather than pulling in a second copy via a
      # fresh pkgs.hyprland reference.
      config.wayland.windowManager.hyprland.package
    ];
    text = ''
      export HYPRWHSPR_ROOT="${hyprwhsprUnwrapped}"
      export PYTHONPATH="${hyprwhsprUnwrapped}/sitecustomize''${PYTHONPATH:+:$PYTHONPATH}"
      # glibc's malloc keeps a bursty process's peak RSS resident (each thread
      # gets its own arena, and freed blocks are kept around for reuse rather
      # than returned to the OS) — a well-documented issue for exactly this
      # workload shape: idle daemon, periodic burst of heavy ONNX Runtime
      # allocation, back to idle. mimalloc actively purges freed pages back
      # to the OS instead — it's also what onnxruntime's own docs recommend
      # pairing it with, and now that enable_cpu_mem_arena=False sends every
      # tensor allocation straight to the system allocator (rather than
      # ONNX Runtime's own pool), mimalloc's specific strength — many small,
      # frequent allocations — is exactly our post-arena-disable pattern.
      export LD_PRELOAD="${pkgs.mimalloc}/lib/libmimalloc.so.3''${LD_PRELOAD:+:$LD_PRELOAD}"
      export MIMALLOC_PURGE_DELAY="5000" # ms before an unused page is purged back to the OS
      ${optionalString cfg.micOsd.enable ''
        export GI_TYPELIB_PATH="${hyprwhsprGiTypelibPath}''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}"
      ''}
      LIB_DIR="${hyprwhsprUnwrapped}/lib"

      # Mirrors upstream bin/hyprwhspr's dispatch: management subcommands go
      # through cli.py, anything else (i.e. no args, as systemd invokes it)
      # runs the service itself via main.py. Unlike upstream, both always run
      # under this Nix-built interpreter — there's no separate self-managed
      # venv to fall back to here.
      #
      # exec -a renames argv[0] to "hyprwhspr" so ps/htop/systemd show that
      # instead of the interpreter's own name (e.g. "python3.14"). It must
      # keep argv[0]'s directory component pointing at the real python3's
      # bin/ dir — CPython's withPackages env is a symlink farm whose site
      # library location is found by walking up from argv[0]'s directory,
      # not by resolving the symlink, so a bare "hyprwhspr" (no directory)
      # would silently fall back to the base interpreter and lose every
      # withPackages dependency (sounddevice included).
      PYTHON_BIN="$(command -v python3)"
      if [[ "''${1:-}" =~ ^(update|setup|install|config|waybar|noctalia|systemd|status|model|validate|uninstall|backend|state|mic-osd|keyboard|record|test|transcribe)$ ]]; then
        exec -a "$(dirname "$PYTHON_BIN")/hyprwhspr" "$PYTHON_BIN" -OO -B "$LIB_DIR/cli.py" "$@"
      fi
      exec -a "$(dirname "$PYTHON_BIN")/hyprwhspr" "$PYTHON_BIN" -OO -B "$LIB_DIR/main.py" "$@"
    '';
  };

  hyprwhsprConfig = {
    "$schema" = "https://raw.githubusercontent.com/goodroot/hyprwhspr/main/share/config.schema.json";

    # CPU-only, no GPU, low RAM: Parakeet TDT v3 via onnx-asr, int8-quantized.
    transcription_backend = "onnx-asr";
    onnx_asr_model = cfg.onnxAsrModel;
    onnx_asr_quantization = cfg.onnxAsrQuantization;
    onnx_asr_use_vad = true;

    language = "en";

    # Shortcut detection goes through the Hyprland bind below instead of
    # evdev, so hyprwhspr never needs raw /dev/input access or 'input'-group
    # membership. Text injection stays on its default (clipboard + wtype
    # paste keystroke), which also needs no special device permissions on a
    # wlroots compositor like Hyprland.
    use_hypr_bindings = true;

    mic_osd_enabled = cfg.micOsd.enable;
  } // cfg.extraSettings;
in
{
  options.${namespace}.desktop.hyprland.hyprwhspr = with types; {
    enable = mkBoolOpt false "Enable hyprwhspr: offline, system-wide speech-to-text dictation for Hyprland (English, CPU-only Parakeet TDT v3 via onnx-asr — no GPU).";

    shortcut = mkstrOpt "SUPER + ALT + D" "Hyprland bind (hl.bind \"MODS + KEY\" syntax), held to record push-to-talk style: recording starts on press and stops (transcribing) on release.";

    onnxAsrModel = mkstrOpt "nemo-parakeet-tdt-0.6b-v3" "ONNX ASR model (CPU-optimized). Downloaded from Hugging Face on first use.";
    onnxAsrQuantization = mkstrOpt "int8" "Quantization for the ONNX ASR model. int8 keeps CPU/RAM usage low; set to \"\" for fp32.";

    micOsd.enable = mkBoolOpt true "Show the animated recording overlay (mic-osd). Pulls in GTK4 + gtk4-layer-shell.";

    extraSettings = mkOpt (types.attrsOf types.anything) { }
      "Extra raw keys merged into hyprwhspr's config.json, overriding this module's defaults. See https://github.com/goodroot/hyprwhspr/blob/main/share/config.schema.json for the full list of available settings.";
  };

  config = mkIf cfg.enable {
    home.packages = [ hyprwhspr ];

    home.file.".config/hyprwhspr/config.json" = {
      force = true; # hyprwhspr's own `config` subcommands treat it as a mutable file
      text = builtins.toJSON hyprwhsprConfig;
    };

    systemd.user.services.hyprwhspr = {
      Unit = {
        Description = "hyprwhspr speech-to-text";
        After = [ "graphical-session.target" "pipewire.service" "wireplumber.service" ];
        PartOf = [ "graphical-session.target" ];
        Wants = [ "pipewire.service" "wireplumber.service" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${hyprwhspr}/bin/hyprwhspr";
        # Belt-and-suspenders cleanup of hyprwhspr's own private virtual
        # keyboard / ydotoold instance, mirroring upstream's unit.
        ExecStopPost = "${pkgs.bash}/bin/bash -c '(pkill -9 -f \"hyprwhspr-virtual-keyboar[d]\" 2>/dev/null; pkill -9 -f \"hyprwhspr-ydotool.soc[k]\" 2>/dev/null) || true'";
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    # Push-to-talk: press starts recording, release stops it (and triggers
    # transcription). Two separate binds on the same combo — the second
    # fires only on key-up (hl.bind's "release" flag, i.e. Hyprland's bindr).
    wayland.windowManager.hyprland.settings.bind = [
      { _args = [ cfg.shortcut (lua ''hl.dsp.exec_cmd("${hyprwhspr}/bin/hyprwhspr record start")'') ]; }
      { _args = [ cfg.shortcut (lua ''hl.dsp.exec_cmd("${hyprwhspr}/bin/hyprwhspr record stop")'') { release = true; } ]; }
    ];
  };
}
