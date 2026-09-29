{ namespace, lib, config, pkgs, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktop.hyprland.sessionRestore;

  # hypr-session-restore has no upstream Nix packaging, so it's fetched here.
  # Single dependency-free Python 3 stdlib file, pinned by commit for
  # reproducibility. Unlike hyprflow (the previous tool here), it was built
  # specifically against Hyprland's Lua-era dispatcher syntax (this repo's
  # `configType = "lua"`), so it needs none of hyprflow's dispatch-string
  # translation or WM-class-guessing patches — it issues `hl.dsp.*` calls
  # natively and replays each window's actual /proc/<pid>/cmdline instead of
  # guessing a binary from its window class.
  hyprSessionRestoreSrc = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/UpayanChatterjee/hypr-session-restore/d281be7fb5153e1a656d95263b349b93a7301aa7/hypr-session-restore";
    hash = "sha256-sg8Y/j9D9+Z1E9KFLobIRO0KZWy9v8PbYYzocZx4luU=";
  };

  # Patched in pure Nix (rather than substituteInPlace) so the replacement
  # text's own indentation can't collide with `''...''`'s auto-dedent. Both
  # fixes below are already diagnosed upstream with this exact diff
  # (single-maintainer, low-traffic repo — just not merged yet). Re-check
  # both issues are still open when bumping the pinned commit above.
  hyprSessionRestore =
    let
      raw = builtins.readFile hyprSessionRestoreSrc;

      # https://github.com/UpayanChatterjee/hypr-session-restore/issues/4 —
      # the autosave loop can catch every window mid-close (e.g. a power
      # menu that closes them a couple seconds before reboot fires) and
      # wipe the last good snapshot with an empty one. Keep the last
      # non-empty save instead.
      withEmptySessionGuard = builtins.replaceStrings
        [ "        spawned_pids.add(pid)\n\n    os.makedirs(STATE_DIR, exist_ok=True)" ]
        [ "        spawned_pids.add(pid)\n\n    if not windows:\n        return 0\n\n    os.makedirs(STATE_DIR, exist_ok=True)" ]
        raw;

      # https://github.com/UpayanChatterjee/hypr-session-restore/issues/3 —
      # a process that re-execs into an updated build (Discord's Linux
      # updater does this) can end up with /proc/<pid>/cmdline collapsed
      # into a single field containing embedded spaces; split it back into
      # argv before relaunching, or exec_cmd tries to run the whole string
      # as one (nonexistent) binary path.
      withCmdlineSplitFix = builtins.replaceStrings
        [ "    argv = proc_cmdline(pid)\n    if not argv:\n        return None\n    return shlex.join(argv)" ]
        [ "    argv = proc_cmdline(pid)\n    if not argv:\n        return None\n    if len(argv) == 1 and \" \" in argv[0]:\n        argv = shlex.split(argv[0])\n    return shlex.join(argv)" ]
        withEmptySessionGuard;

      # Pin the interpreter instead of relying on `env python3` finding one
      # on PATH (systemd services and the Lua-exec'd login script both run
      # with a minimal PATH).
      withPinnedShebang = builtins.replaceStrings
        [ "#!/usr/bin/env python3" ]
        [ "#!${pkgs.python3}/bin/python3" ]
        withCmdlineSplitFix;
    in
    pkgs.writeTextFile {
      name = "hypr-session-restore";
      executable = true;
      destination = "/bin/hypr-session-restore";
      text = withPinnedShebang;
      meta = {
        description = "Save and restore Hyprland window sessions (macOS-style reopen-on-login)";
        homepage = "https://github.com/UpayanChatterjee/hypr-session-restore";
        license = lib.licenses.mit;
        mainProgram = "hypr-session-restore";
      };
    };

  # "30m" / "24h" / "7d" -> minutes, for `find -mmin`.
  durationToMinutes =
    dur:
    let
      len = builtins.stringLength dur;
      unit = builtins.substring (len - 1) 1 dur;
      n = lib.toInt (builtins.substring 0 (len - 1) dur);
      mult =
        {
          m = 1;
          h = 60;
          d = 1440;
        }
        .${unit} or (throw "sessionRestore.maxAge: unsupported unit '${unit}' in '${dur}' (use m/h/d)");
    in
    n * mult;

  sessionExcludeEnv = optionalString (cfg.excludeClasses != [ ])
    ''export HYPR_SESSION_EXCLUDE="${concatStringsSep "," cfg.excludeClasses}"'';

  # Restore-on-login wrapper: hypr-session-restore itself has no maxAge
  # concept, so the staleness check lives here instead of as a tool patch.
  restoreOnLoginScript = pkgs.writeShellApplication {
    name = "hypr-session-restore-login";
    text = ''
      ${sessionExcludeEnv}
      session_dir="''${HYPR_SESSION_DIR:-''${XDG_STATE_HOME:-$HOME/.local/state}/hypr-session-restore}"
      session_file="$session_dir/session.json"
      if [ -f "$session_file" ] && [ -z "$(find "$session_file" -mmin +${toString (durationToMinutes cfg.maxAge)})" ]; then
        exec ${hyprSessionRestore}/bin/hypr-session-restore restore
      fi
    '';
  };
in
{
  options.${namespace}.desktop.hyprland.sessionRestore = with types; {
    enable =
      mkBoolOpt false
        "Enable session restore: save and restore Hyprland window sessions (positions, workspaces, monitor layout, terminal cwd) across reboots.";

    restoreOnLogin = mkBoolOpt true "Restore the most recent session (if not older than maxAge) when Hyprland starts.";
    maxAge = mkstrOpt "24h" "Skip restore-on-login if the saved session is older than this (e.g. 30m, 24h, 7d).";

    autosave = {
      enable = mkBoolOpt true "Periodically autosave the session via a systemd user timer.";
      interval = mkstrOpt "1min" "How often to autosave (systemd OnUnitActiveSec= duration).";
    };

    excludeClasses = mkOpt (types.listOf types.str) [ ]
      "Extra window classes to never save/restore (e.g. bars, trays, launchers your autostart already handles).";
  };

  config = mkIf cfg.enable {
    home.packages = [ hyprSessionRestore ];

    systemd.user.services.hypr-session-restore-autosave = mkIf cfg.autosave.enable {
      Unit = {
        Description = "Hypr session restore autosave";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        Environment = mkIf (cfg.excludeClasses != [ ]) [ "HYPR_SESSION_EXCLUDE=${concatStringsSep "," cfg.excludeClasses}" ];
        ExecStart = "${hyprSessionRestore}/bin/hypr-session-restore save";
      };
    };

    systemd.user.timers.hypr-session-restore-autosave = mkIf cfg.autosave.enable {
      Unit.Description = "Periodically autosave the Hyprland session";
      Timer = {
        OnStartupSec = "1min";
        OnUnitActiveSec = cfg.autosave.interval;
        Unit = "hypr-session-restore-autosave.service";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    # Restore the most recent session when Hyprland starts.
    wayland.windowManager.hyprland.extraConfig = mkIf cfg.restoreOnLogin ''
      hl.on("hyprland.start", function()
        hl.dispatch(hl.dsp.exec_cmd("${restoreOnLoginScript}/bin/hypr-session-restore-login"))
      end)
    '';
  };
}
