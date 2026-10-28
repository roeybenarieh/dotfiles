{ system, namespace, inputs, lib, pkgs, config, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.omnigent;
in
{
  options.${namespace}.omnigent = with types; {
    enable = mkBoolOpt false "Enable Omnigent, the multi-agent coding CLI/meta-harness (orchestrates Claude Code, Codex, Cursor, and others) with its local web console.";
    noAutoOpenBrowser = mkBoolOpt false "Suppress the automatic browser tab opened by `omnigent start` / `omni host` (sets OMNIGENT_HOST_NO_OPEN=1) and by `omnigent run` per conversation (sets auto_open_conversation=false in ~/.omnigent/config.yaml).";
    hideStatusLine = mkBoolOpt false "Hide the tmux status line Omnigent prints at the bottom of every managed terminal (e.g. `omni opencode`), showing \"Omnigent: http://127.0.0.1:6767/c/<id>\". There's no config/env knob for this (it's hardcoded in omnigent/inner/terminal.py's `_tmux_status_option_commands`), so this patches it in at runtime via a `usercustomize.py` import hook rather than editing the vendored Nix-store copy, so it keeps working across omnigent updates.";

    tailscale = {
      enable = mkBoolOpt false "Make `omnigent start` / `omni start` (and `omnigent host --background` / `omni host --background`) transparently expose the local Omnigent server (default port 6767) to every device on your tailnet over HTTPS via `tailscale serve` (never `funnel` — this deliberately stays off the public internet), with Omnigent's trusted-origin/base-URL settings pointed at the resulting `https://<machine>.ts.net` address. The server itself keeps listening on 127.0.0.1 only — Tailscale Serve is the sole route in, so it's reachable from every device on your tailnet but never from the plain LAN. Requires `extra.tailscale.enable = true` and `extra.tailscale.operator` set to this user at the NixOS level. The connect URL is printed to the terminal on every `start`, since it depends on your tailnet's name and isn't known until you're logged in.";
    };
  };

  config = mkIf cfg.enable (
    let
      omnigentUnwrapped = inputs.llm-agents-nix.packages.${system}.omnigent;

      # `omni opencode` launches opencode-native's builtin `opencode-native-ui`
      # agent, which spawns `opencode serve` with a per-session, isolated
      # XDG_CONFIG_HOME (~/.omnigent/opencode-native/<hash>/xdg-config) — so the
      # real ~/.config/opencode/opencode.json, and with it the `mcp` and `lsp` blocks
      # `extra.opencode`'s `enableMcpIntegration` renders there, is invisible
      # inside that session. Omnigent's own cross-boundary merge
      # (maybe_merge_user_provider_config in omnigent's opencode_native/provider.py)
      # only carries over `provider`, `model`, and `plugin` from that file — `mcp`
      # isn't on that list, and there's no config/env knob to add it (confirmed by
      # reading that function: it's a hardcoded set of keys, not configurable).
      # The agent-spec-level `mcp_servers:` field would be the "native" fix, but
      # `opencode-native-ui` is an Omnigent builtin, not something this repo owns.
      #
      # Since `plugin` IS on the carry-over list, smuggle the fix through it: a
      # plugin that, at session-start, reads the real opencode.json off disk
      # itself (bypassing the isolated XDG_CONFIG_HOME) and merges its `mcp`,
      # `lsp`, and `permission` keys into the session config. Read at
      # plugin-run time rather than inlining the JSON at Nix-build time,
      # because `enableMcpIntegration` only computes the merged MCP servers as
      # a local value used to render that one file — it never writes the
      # merge back into `programs.opencode.settings.mcp`, so reading that
      # option here would just bake in `{}`.
      #
      # `permission` rides the same bypass for the same reason: `extra.opencode`
      # sets `permission: "allow"` in the REAL opencode.json so interactive
      # `opencode` sessions never prompt, but that's exactly the key
      # `maybe_merge_user_provider_config` in omnigent's opencode_native/provider.py
      # does NOT carry across the isolated-XDG_CONFIG_HOME boundary (only
      # provider/model/plugin are). Omnigent 0.15 instead synthesizes
      # `permission: "ask"` for the session (so every call depends on its SSE
      # forwarder replying; child/sub-agent sessions and runner restarts
      # aren't covered, which is when the TUI starts prompting), and the
      # plugin below overrides it with the real value. TRADEOFF: that bypasses
      # Omnigent's per-tool-call policy gate for OpenCode (see the comment in
      # the plugin body); harmless while no policies are configured. Without that, OpenCode asks for every category -- including MCP tool calls, which is why
      # `omni opencode`/`opencode` (aliased) still shows a native "Permission
      # required" TUI card for things like an MCP server's first tool call,
      # even though bash/edit/webfetch are separately auto-resolved upstream
      # by Omnigent's own policy-engine SSE forwarder (no `policies:`
      # configured anywhere, so it fast-paths ALLOW and auto-replies before
      # the TUI ever renders a card for those three).
      opencodeSharedMcpPlugin = pkgs.writeText "opencode-shared-mcp.js" ''
        const fs = require("fs");

        export const SharedMcpPlugin = async () => {
          // Omnigent *copies* the real auth.json into each session's isolated
          // XDG_DATA_HOME (seed_opencode_auth). Anthropic OAuth refresh tokens
          // rotate on use, so the first copy to refresh invalidates every other
          // copy and the real file ("invalid_grant" -> manual /connect). Symlink
          // instead so all sessions share one token store, like omnigent does
          // for codex's auth.json.
          try {
            const real = ${builtins.toJSON "${config.xdg.dataHome}/opencode/auth.json"};
            const data = process.env.XDG_DATA_HOME;
            const mine = data && data + "/opencode/auth.json";
            if (mine && mine !== real && fs.existsSync(real)) {
              fs.rmSync(mine, { force: true });
              fs.symlinkSync(real, mine);
            }
          } catch (e) {}
          // omnigent also points XDG_CONFIG_HOME at the isolated per-session
          // dir, hiding the real gh login (~/.config/gh/hosts.yml) from the
          // bash tool. Copy it in on every session start so a re-login in the
          // real config propagates on the next session.
          try {
            const realGh = ${builtins.toJSON "${config.xdg.configHome}/gh"};
            const cfgHome = process.env.XDG_CONFIG_HOME;
            const myGh = cfgHome && cfgHome + "/gh";
            if (myGh && myGh !== realGh && fs.existsSync(realGh)) {
              fs.rmSync(myGh, { recursive: true, force: true });
              fs.cpSync(realGh, myGh, { recursive: true });
            }
          } catch (e) {}
          // The attached TUI (`opencode attach`) reads tui.json from the isolated
          // XDG_CONFIG_HOME, which omnigent never fills, so TUI plugins (quota
          // panel, startup dialog) are missing there. Copy the real file in on
          // every session start, same as the gh copy above.
          try {
            const realTui = ${builtins.toJSON "${config.xdg.configHome}/opencode/tui.json"};
            const cfgHome = process.env.XDG_CONFIG_HOME;
            const myTui = cfgHome && cfgHome + "/opencode/tui.json";
            if (myTui && myTui !== realTui && fs.existsSync(realTui)) {
              fs.mkdirSync(cfgHome + "/opencode", { recursive: true });
              fs.rmSync(myTui, { force: true });
              fs.copyFileSync(realTui, myTui);
            }
          } catch (e) {}
          return {
          config: async (config) => {
            try {
              const raw = fs.readFileSync(${builtins.toJSON "${config.xdg.configHome}/opencode/opencode.json"}, "utf8");
              const parsed = JSON.parse(raw);
              if (parsed && typeof parsed.mcp === "object" && parsed.mcp !== null) {
                config.mcp = { ...parsed.mcp, ...config.mcp };
              }
              if (parsed && typeof parsed.lsp === "object" && parsed.lsp !== null && config.lsp !== false) {
                config.lsp = { ...parsed.lsp, ...config.lsp };
              }
              // Override unconditionally: omnigent 0.15 always synthesizes
              // `permission: "ask"`, so an `=== undefined` guard never fires.
              // TRADEOFF: with "allow", opencode never emits permission.asked, so
              // Omnigent's policy engine (the SSE forwarder's PHASE_TOOL_CALL
              // gate) no longer sees OpenCode tool calls. Fine while no
              // `policies:` are configured; if you add any, they will NOT apply
              // to `omni opencode` (REQUEST/TOOL_RESULT phases still do, via
              // omnigent-policy.js). Drop this override to get them back, at the
              // cost of the stray permission prompts.
              //
              // Expand a bare action string (e.g. "allow", as extra.opencode
              // sets) into the equivalent per-category object instead of
              // assigning it directly: the plugin config-hook's own schema
              // (bundled opencode-native's chunk-etyajq96.js as of 1.18.x)
              // rejects that shorthand with `Expected PermissionConfig |
              // undefined, got "allow"` and crashes `omni opencode` on
              // startup, even though it's valid in opencode.json itself.
              // The object form's own string->object decoder (same bundle,
              // `GH=(_)=>typeof _==="string"?{"*":_}:_`) rewrites a bare
              // string into `{"*": action}` rather than a per-category
              // list — "*" is a real catch-all rest key in its schema
              // (`g5=D.StructWithRest(D.Struct({read,edit,bash,...}),
              // [D.Record(D.String, x1)])`), consulted for any tool/category
              // not named explicitly, which includes every MCP server tool
              // (each keyed by its own tool name, never one of the fixed
              // categories below). Set both: "*" for blanket/future/MCP
              // coverage, and the named keys in case some code path reads a
              // category directly without ever falling back to "*".
              if (parsed && parsed.permission !== undefined) {
                const perm = parsed.permission;
                config.permission = typeof perm === "string" ? {
                  "*": perm,
                  read: perm, edit: perm, glob: perm, grep: perm, list: perm, bash: perm,
                  task: perm, external_directory: perm, todowrite: perm, question: perm,
                  webfetch: perm, websearch: perm, lsp: perm, doom_loop: perm, skill: perm,
                } : perm;
              }
            } catch (e) {
              // Best-effort: never break opencode startup over this.
            }
          },
          };
        };
      '';

      # Omnigent hardcodes a tmux `status-left` of
      # `Omnigent: #{@omnigent-conversation-link}` for every managed terminal
      # session (_tmux_status_option_commands in omnigent/inner/terminal.py) —
      # no config key or env var controls it (gated below by cfg.hideStatusLine).
      #
      # The same mechanism also always patches a second, unrelated bug: the
      # `omni` CLI builds the background host daemon's entire environment
      # through a fixed allowlist (`_LOCAL_DAEMON_ENV_ALLOWLIST` in
      # omnigent/cli.py, no config/env override) before ever spawning it.
      # WAYLAND_DISPLAY/DISPLAY aren't on it, so a daemon-managed terminal
      # (e.g. `omni claude`) can't reach the compositor for clipboard tools
      # (wl-paste/xclip), breaking native image paste (Ctrl+V) there even
      # though it works in a plain, unwrapped `claude`. There's a *separate*
      # allowlist + override (OMNIGENT_RUNNER_ENV_PASSTHROUGH, set in
      # home.sessionVariables below) for what the daemon forwards to the
      # runners it spawns, but that only forwards names already present in
      # the daemon's own environment — which this first allowlist strips
      # before the daemon ever starts.
      #
      # A third layer still drops them even with both of the above fixed:
      # the claude-native terminal's tmux `new-session` is ultimately spawned
      # by a short-lived runner/worker process (reparented to the daemon by
      # the time it's inspectable), and that process's own environment
      # doesn't reliably carry WAYLAND_DISPLAY/DISPLAY through to the final
      # `env=` dict TerminalInstance.launch() passes to tmux, regardless of
      # the OMNIGENT_RUNNER_ENV_PASSTHROUGH passthrough. Rather than chase
      # that one spawn path, this also patches
      # build_native_claude_terminal_env (omnigent/harnesses/claude_native/main.py)
      # — the small per-terminal env-override dict that
      # TerminalInstance.launch() always `env.update()`s in last, after any
      # other stripping — to copy WAYLAND_DISPLAY/DISPLAY from its own
      # process's environment (which, being runner/zygote-descended, does
      # have them) directly into that override dict. All three layers need
      # fixing for clipboard paste to work end-to-end.
      #
      # Both patches run at runtime via a PYTHONPATH-injected module that
      # `site.py` auto-imports at interpreter startup, instead of editing the
      # vendored files in the Nix store directly, so this survives omnigent
      # version bumps.
      #
      # It's named `usercustomize.py`, not `sitecustomize.py`: nixpkgs' own
      # Python wrapper ships its own `sitecustomize.py` (for NIX_PYTHONPATH
      # handling) earlier on sys.path than anything we can inject, and
      # Python's import system only loads the *first* module named
      # `sitecustomize` it finds — so ours would silently never run.
      # `usercustomize` is a second, independent auto-import hook `site.py`
      # runs right after `sitecustomize`, and nothing else in this stack
      # defines one, so it isn't subject to the same ordering race. It's only
      # imported when `ENABLE_USER_SITE` is true, which nixpkgs' Python
      # disables by default (`PYTHONNOUSERSITE=true`) — hence clearing that
      # env var below whenever this module is injected. That alone isn't
      # enough, though: the package's own `bin/<name>` wrapper (nixpkgs'
      # buildPythonApplication convention) unconditionally re-exports
      # `PYTHONNOUSERSITE=true` partway through its own body, *after* ours
      # runs and *before* it execs the real binary — silently undoing our
      # override again. mkOmnigentWrapper below works around that by
      # sourcing everything that wrapper does except its own trailing exec,
      # then re-clearing PYTHONNOUSERSITE itself before exec-ing the real
      # binary directly.
      runtimePatchesSitecustomize = pkgs.writeTextDir "usercustomize.py" ''
        import os
        import sys
        import importlib.abc

        class _OmnigentRuntimePatches(importlib.abc.MetaPathFinder):
          _TARGETS = {"omnigent.cli", "omnigent.harnesses.claude_native.main", "omnigent.tools.manager"${optionalString cfg.hideStatusLine '', "omnigent.inner.terminal"''}}

          def find_spec(self, name, path, target=None):
            if name not in self._TARGETS:
              return None
            for finder in sys.meta_path:
              if finder is self:
                continue
              find_spec = getattr(finder, "find_spec", None)
              if find_spec is None:
                continue
              spec = find_spec(name, path, target)
              if spec is None or spec.loader is None:
                continue
              original_exec_module = spec.loader.exec_module

              def exec_module(module, _original=original_exec_module, _name=name):
                _original(module)
                if _name == "omnigent.cli" and hasattr(module, "_LOCAL_DAEMON_ENV_ALLOWLIST"):
                  module._LOCAL_DAEMON_ENV_ALLOWLIST = (
                    frozenset({"WAYLAND_DISPLAY", "DISPLAY"}) | module._LOCAL_DAEMON_ENV_ALLOWLIST
                  )
                if _name == "omnigent.harnesses.claude_native.main" and hasattr(
                  module, "build_native_claude_terminal_env"
                ):
                  _original_build_env = module.build_native_claude_terminal_env

                  def _patched_build_env(claude_config, _orig=_original_build_env):
                    env = _orig(claude_config)
                    for _var in ("WAYLAND_DISPLAY", "DISPLAY"):
                      _val = os.environ.get(_var)
                      if _val:
                        env[_var] = _val
                    return env

                  module.build_native_claude_terminal_env = _patched_build_env${optionalString cfg.hideStatusLine "\n        if _name == \"omnigent.inner.terminal\" and hasattr(module, \"_tmux_status_option_commands\"):\n          module._tmux_status_option_commands = lambda: [[\"set-option\", \"-g\", \"status\", \"off\"]]"}
                if _name == "omnigent.tools.manager" and hasattr(module, "ToolManager"):
                  # Drop the always-on embedded-browser tools (browser_*);
                  # the Playwright MCP server covers browser automation.
                  module.ToolManager._register_browser_tools = lambda self: None

              spec.loader.exec_module = exec_module
              return spec
            return None

        sys.meta_path.insert(0, _OmnigentRuntimePatches())
      '';

      # Any command can auto-start the local server, so all invocations need
      # the trusted origin. Only explicit background starts configure Serve.
      tailscaleServeSetup = ''
        ts_host=$(${pkgs.tailscale}/bin/tailscale status --json | ${pkgs.jq}/bin/jq -r '.Self.DNSName // empty' | sed 's/\.$//') || ts_host=""
        if [[ -z "$ts_host" ]]; then
          if [[ "$should_serve" == 1 ]]; then
            echo "$0: tailscale isn't signed in yet -- run 'sudo tailscale up' first; starting without exposing it over your tailnet" >&2
          fi
        else
          export OMNIGENT_WS_ALLOWED_ORIGINS="https://$ts_host"
          export OMNIGENT_ACCOUNTS_BASE_URL="https://$ts_host"
          if [[ "$should_serve" == 1 ]]; then
            ${pkgs.tailscale}/bin/tailscale serve --bg --https=443 http://localhost:6767
            echo "Omnigent: reachable from any device on your tailnet at https://$ts_host" >&2
          fi
        fi
      '';

      mkOmnigentWrapper = name: pkgs.writeShellScriptBin name (''
        set -euo pipefail
        export PYTHONPATH="${runtimePatchesSitecustomize}''${PYTHONPATH:+:}''${PYTHONPATH:-}"
        # nixpkgs' Python sets PYTHONNOUSERSITE=true by default, which
        # disables the usercustomize.py hook above entirely regardless of
        # PYTHONPATH ordering (see comment on runtimePatchesSitecustomize).
        export PYTHONNOUSERSITE=
      '' + optionalString cfg.tailscale.enable ''

        should_serve=0
        case "''${1:-}" in
          start) should_serve=1 ;;
          host)
            for arg in "$@"; do
              [[ "$arg" == "--background" ]] && should_serve=1
            done
            ;;
        esac
        ${tailscaleServeSetup}
      '' + ''

        # Don't exec straight into the package's own bin/${name}: that
        # wrapper re-forces PYTHONNOUSERSITE=true after the export above
        # (see comment on runtimePatchesSitecustomize), which would disable
        # our patch again. Source everything it does except its own
        # trailing exec (always its last line, per nixpkgs'
        # buildPythonApplication wrapper generator) to pick up its
        # PATH/PYTHONPATH setup, then re-clear PYTHONNOUSERSITE and exec
        # the real binary ourselves.
        source <(${pkgs.coreutils}/bin/head -n -1 "${omnigentUnwrapped}/bin/${name}")
        export PYTHONNOUSERSITE=
        exec -a "$0" "${omnigentUnwrapped}/bin/.${name}-wrapped" "$@"
      '');

      # Always wrapped now: the host-daemon-env patch above (clipboard fix)
      # applies unconditionally, independent of hideStatusLine/tailscale.
      omnigent = pkgs.symlinkJoin {
        name = "omnigent-${omnigentUnwrapped.version or "wrapped"}";
        paths = [ (mkOmnigentWrapper "omnigent") (mkOmnigentWrapper "omni") ];
      };
    in
    {
      home.packages = [ omnigent ];

      # See opencodeSharedMcpPlugin above. Concatenates onto whatever plugin
      # list extra.opencode's own module sets (list-typed leaves of
      # pkgs.formats.json merge across modules like any other listOf option),
      # so this only takes effect when extra.opencode is also enabled.
      programs.opencode.settings.plugin = mkIf config.${namespace}.opencode.enable [
        "${opencodeSharedMcpPlugin}"
      ];

      # Route `claude`/`codex` through Omnigent's harness selection instead of
      # invoking the underlying CLIs directly. `omni codex` forwards
      # unrecognized args straight through to Codex, so it can carry the same
      # per-directory trust override as extra.codex's own `codex` alias
      # (config.toml is a read-only Nix store symlink, so this can't be
      # persisted and must be injected on every invocation instead).
      # `mkForce` wins over extra.codex's alias when both modules are enabled.
      home.shellAliases = {
        claude = "omni claude";
        codex = "omni codex";
        # NOT "omni opencode --auto": omnigent forwards every extra arg to
        # BOTH `opencode serve` and `opencode attach` (app_server.py's
        # _build_serve_args/_build_attach_args), and `attach` has no `--auto`
        # flag (it's a top-level `opencode [project]` flag only) — yargs
        # rejects it and the TUI process exits immediately, killing the tmux
        # pane on launch. It's also unnecessary: `omni opencode` has its own
        # permission gate (omnigent.harnesses.opencode_native's SSE forwarder
        # intercepts OpenCode's permission.v2.asked events and asks Omnigent's
        # policy engine), which `extra.opencode`'s own `permission: "allow"`
        # in opencode.json can't reach — but with no `policies:` configured
        # anywhere in ~/.omnigent/config.yaml and no guardrails on the
        # built-in `opencode-native-ui` agent spec, that gate's own
        # fast-path (any_policies_apply) already returns ALLOW for every
        # call, so bash/edit/webfetch all run with zero prompts as-is.
        opencode = "omni opencode";
      };

      home.sessionVariables = {
        DO_NOT_TRACK = "1";
        # Second half of the clipboard-paste fix (see runtimePatchesSitecustomize
        # above for the first half). Omnigent's host daemon spawns each managed
        # terminal's runner (the process tree that ends up running
        # `claude`/`codex`/`opencode` in its tmux pane) through its own env
        # ALLOWLIST (_build_runner_env in omnigent/host/connect.py) that strips
        # everything not explicitly named — locale/OTEL/MLflow prefixes plus a
        # few named credentials. This is the var Omnigent reads to extend that
        # allowlist with operator-chosen names, so WAYLAND_DISPLAY/DISPLAY reach
        # the runner — but only once they're in the daemon's own environment to
        # begin with, which is what the usercustomize.py patch above fixes.
        OMNIGENT_RUNNER_ENV_PASSTHROUGH = "WAYLAND_DISPLAY,DISPLAY";
      } // optionalAttrs cfg.noAutoOpenBrowser {
        # Only suppresses the browser tab opened by `omnigent start` / `omni host`
        # for the host web UI. `omnigent run`'s per-conversation auto-open is a
        # separate code path gated by the `auto_open_conversation` key in
        # ~/.omnigent/config.yaml, with no environment-variable override — hence
        # the activation script below.
        OMNIGENT_HOST_NO_OPEN = "1";
      };

      # `omnigent run` defaults to opening a browser tab per conversation and is
      # only controllable via ~/.omnigent/config.yaml (no env var), so persist
      # the setting through the CLI's own config writer to avoid clobbering any
      # other keys (default_agent, harness, auth, ...) already in that file.
      home.activation.omnigentNoAutoOpenConversation = inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${omnigent}/bin/omnigent config set --global \
          auto_open_conversation=${if cfg.noAutoOpenBrowser then "false" else "true"}
      '';
    }
  );
}
