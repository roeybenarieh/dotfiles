{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.mcp;

  # Opens a URL in the running Chromium through its remote-debugging port
  # (9222, set by the claude module's commandLineArgs). Used as the
  # Playwright MCP "browser" executable for --extension, see the server below.
  playwrightExtensionOpener = pkgs.writeShellApplication {
    name = "playwright-extension-open";
    runtimeInputs = [ pkgs.curl ];
    text = ''
      url="''${!#}"
      curl -s -X PUT --get --data-urlencode "$url" http://127.0.0.1:9222/json/new >/dev/null
    '';
  };

  # headroom's MCP server (below) is a thin stdio client: its
  # compress/retrieve/stats tools only report real data when a `headroom
  # proxy` daemon is actually running and Claude Code's traffic flows through
  # it — the two are deliberately decoupled (the proxy is meant to be a
  # single long-lived process shared across many short-lived MCP-server
  # sessions, not spawned per-session) so this needs its own systemd service
  # plus routing Claude Code's Anthropic traffic at it, below.
  headroomProxyPort = 8787;

  # Always resolve `uvx` from the Nix store rather than relying on a plain
  # "uvx" string, which would depend on PATH lookup at runtime.
  uvx = lib.getExe' pkgs.uv "uvx";

  # The `headroom` entry script re-execs the venv's `python`, so the kernel
  # process name (what top/ps/htop show) is just "python". comm comes from the
  # exec'd filename and can't be set by systemd, so set it in-process via
  # prctl(PR_SET_NAME = 15). Max 15 bytes; "headroom-proxy" is 14.
  headroomProxyScript = pkgs.writeText "headroom-proxy.py" ''
    import ctypes, sys
    ctypes.CDLL(None).prctl(15, b"headroom-proxy")
    sys.argv = ["headroom", "proxy", "--port", "${toString headroomProxyPort}"]
    from headroom.cli import main
    sys.exit(main())
  '';

  # OpenCode's native `openai` provider (ChatGPT-OAuth) honors neither
  # `provider.openai.options.baseURL` nor an `OPENAI_BASE_URL` env var —
  # verified empirically with `ss`-traced live `opencode run` tests: traffic
  # went straight to the real remote host both times. Its OAuth code path
  # builds the request client itself (`createOpenAI(options).responses(...)`)
  # without threading either override through. headroom ships its own fix for
  # exactly this: a self-contained OpenCode plugin (built via
  # `npm run build:standalone`, inlining every dependency) that monkey-patches
  # `fetch`/`http`/`https`/`http2`/`child_process` at the Node runtime level,
  # so it reroutes traffic regardless of what any provider SDK does internally.
  # Fetched straight out of the `headroom-ai` PyPI wheel (same package that
  # provides the MCP server and proxy above) rather than the mutable
  # `~/.cache/uv` path it unpacks to at runtime, so this is reproducible.
  headroomOpencodeWheel = pkgs.fetchurl {
    url = "https://files.pythonhosted.org/packages/60/fc/8411d3188a485f6e3a227da08d5140bdcc62a07e8a85c73ab1e9a822bf09/headroom_ai-0.39.1-cp310-abi3-manylinux_2_28_x86_64.whl";
    hash = "sha256-6duyJIOgiNmaRmxQan13+gSJv4xbGf6zUBCsW9Jcl6Q=";
  };
  headroomOpencodeTransportPlugin = pkgs.runCommand "entry.opencode.js" { } ''
    ${lib.getExe' pkgs.unzip "unzip"} -p ${headroomOpencodeWheel} headroom/providers/opencode/_dist/entry.opencode.js > $out
  '';

  # The transport plugin above reads its proxy target from `options.proxyUrl`,
  # falling back to `process.env.HEADROOM_PROXY_URL`/`HEADROOM_BASE_URL`
  # (ultimately `http://localhost:8787` — this repo's port, incidentally). Set
  # it explicitly from a tiny bootstrap plugin, same trick as the Anthropic one
  # above, loaded first so the env var exists before the transport plugin's own
  # default export runs and resolves it.
  headroomOpencodeProxyUrlPlugin = pkgs.writeText "headroom-proxy-url.mjs" ''
    export default async () => {
      process.env.HEADROOM_PROXY_URL = "http://127.0.0.1:${toString headroomProxyPort}";
      return {};
    };
  '';

  # OpenCode's native `anthropic` provider's AI SDK treats `ANTHROPIC_BASE_URL`
  # as a complete replacement for its default base (`https://api.anthropic.com/v1`)
  # rather than a host to graft `/v1` onto, so the request path becomes
  # `<ANTHROPIC_BASE_URL>/messages` with no `/v1` segment. The
  # `opencode-anthropic-auth` plugin's own `rewriteUrl()` (which reads this same
  # env var to override the request's protocol+host) only ever swaps host, never
  # path, so it inherits whatever path the SDK already built. Confirmed directly
  # against the proxy: `POST /messages` (no `/v1`) → immediate 404, byte-for-byte
  # the `AI_APICallError: Not Found` seen in every OpenCode request once this
  # plugin was in the mix — the `/v1` suffix below is what the bare-host version
  # of this plugin was missing.
  headroomOpencodeAnthropicBaseUrlPlugin = pkgs.writeText "headroom-anthropic-base-url.mjs" ''
    export default async () => {
      process.env.ANTHROPIC_BASE_URL = "http://127.0.0.1:${toString headroomProxyPort}/v1";
      return {};
    };
  '';
in
{
  options.${namespace}.mcp = with types; {
    enable = mkBoolOpt false "Enable the shared MCP (Model Context Protocol) server registry, consumed by AI coding harnesses (Claude Code, Codex, ...) via their `enableMcpIntegration` option.";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.nodejs ];

    programs.mcp = {
      enable = true;

      servers = {
        context7 = {
          url = "https://mcp.context7.com/mcp?client=claude-code-nix";
        };
        # Drives the user's own Chromium through the Playwright browser
        # extension (see below), so agent actions show up in the visible
        # browser session.
        # Credentials (PLAYWRIGHT_MCP_EXTENSION_TOKEN) live in
        # ~/.config/playwright-mcp/env (chmod 600), sourced at launch so they
        # never reach /nix/store. Same pattern as the gmail server below.
        playwright = {
          command = lib.getExe (pkgs.writeShellApplication {
            name = "playwright-mcp-extension";
            runtimeInputs = [ pkgs.nodejs ];
            text = ''
              set -a
              # shellcheck source=/dev/null
              . "$HOME/.config/playwright-mcp/env"
              set +a
              # The server "launches" its browser with the connect-page URL as
              # the last argument. Launching Chromium that way opens a second
              # instance that never reaches the running one, so point it at the
              # opener below, which uses the running browser's CDP port instead.
              export PLAYWRIGHT_MCP_EXECUTABLE_PATH="${playwrightExtensionOpener}/bin/playwright-extension-open"
              # Pinned: nixpkgs' 0.0.76 ignores --extension on the MCP path and
              # falls back to an isolated browser; 0.0.83 uses the extension relay.
              exec npx -y @playwright/mcp@0.0.83 --extension
            '';
          });
        };
        # AI coding harnesses (Claude Code, Codex, ...) commonly launch these
        # MCP servers as descendants of an already-Python process (e.g. an
        # Omnigent-orchestrated session) whose PYTHONPATH points at its own
        # pinned `mcp` SDK build. That leaks into every `uvx`-run server here
        # and shadows the `mcp` package version `uvx` actually resolved,
        # breaking servers whose code path needs a newer/different `mcp` API
        # surface (observed: fastmcp's `mcp.server.request_state`, serena's
        # pinned `mcp==2.2.0`). Force each Python-based server to ignore any
        # inherited PYTHONPATH so it only ever sees the `uvx`-managed one.
        headroom = {
          command = uvx;
          args = [ "--from" "headroom-ai[mcp]@latest" "headroom" "mcp" "serve" ];
          env.PYTHONPATH = "";
        };
        serena = {
          command = uvx;
          args = [
            "--from"
            "git+https://github.com/oraios/serena"
            "serena"
            "start-mcp-server"
            "--project-from-cwd"
            "--context"
            "claude-code"
            "--open-web-dashboard"
            "False"
          ];
          env.PYTHONPATH = "";
        };
        # Gmail over IMAP (app password, no OAuth). Credentials are NOT in
        # Nix: the wrapper sources ~/.config/gmail-imap/env (chmod 600) at
        # launch, so the secret never reaches /nix/store. Pinned npm version
        # because npx fetches it at runtime.
        gmail = {
          command = lib.getExe (pkgs.writeShellApplication {
            name = "gmail-mcp-imap";
            runtimeInputs = [ pkgs.nodejs ];
            text = ''
              set -a
              # shellcheck source=/dev/null
              . "$HOME/.config/gmail-imap/env"
              set +a
              exec npx -y gmail-mcp-imap@1.0.2
            '';
          });
        };
      };
    };

    # Playwright Extension (Microsoft, Chrome Web Store): the bridge that lets
    # the `playwright` MCP server above attach to this browser profile.
    programs.chromium.extensions = [ "mmlmfjhmonkocbjadbfplnigmagldckm" ];

    systemd.user.services.headroom-proxy = {
      Unit = {
        Description = "Headroom context-optimization proxy for Anthropic API traffic";
      };
      Service = {
        ExecStart = "${uvx} --from headroom-ai[proxy]@latest python ${headroomProxyScript}";
        Environment = [
          "PYTHONPATH=" # see the PYTHONPATH note above
          # headroom defers tool schemas behind Anthropic's server-side
          # `tool_search_tool_regex` by default; opencode can't execute that
          # tool ("Model tried to call unavailable tool").
          "HEADROOM_TOOL_SEARCH=0"
        ];
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = [ "default.target" ];
    };

    # Route Claude Code's Anthropic traffic through the proxy above so
    # headroom's MCP tools (compress/retrieve/stats) have real traffic to
    # report on, instead of always showing zero compressions. headroom's
    # proxy relays whatever auth the client sends (API key or the Claude
    # Pro/Max OAuth flow — it even polls that subscription's usage stats
    # itself) straight through to the real Anthropic API, so this doesn't
    # change how Claude Code authenticates.
    programs.claude-code.settings.env = mkIf config.${namespace}.claude.enable {
      ANTHROPIC_BASE_URL = "http://127.0.0.1:${toString headroomProxyPort}";
    };

    # Route Codex the same way. Codex's ChatGPT-OAuth login *does* honor a
    # custom base_url on a `[model_providers.<id>]` entry (unlike opencode's
    # — see below), verified by running headroom's own `headroom init codex`
    # against a throwaway copy of config.toml and diffing the result; this is
    # that same shape, added declaratively instead of via headroom's
    # imperative installer (which can't write to Home Manager's read-only
    # config.toml symlink anyway, and manages its own competing proxy
    # supervisor we don't want alongside the systemd service above).
    # `requires_openai_auth = true` is what keeps it on the existing ChatGPT
    # OAuth token instead of expecting a plain API key.
    programs.codex.settings = mkIf config.${namespace}.codex.enable {
      model_provider = "headroom";
      openai_base_url = "http://127.0.0.1:${toString headroomProxyPort}/v1";
      model_providers.headroom = {
        name = "Headroom proxy";
        base_url = "http://127.0.0.1:${toString headroomProxyPort}/v1";
        supports_websockets = true;
        requires_openai_auth = true;
      };
    };

    # The "anthropic" provider (Claude Pro/Max OAuth, via opencode/default.nix's
    # `opencode-anthropic-auth` plugin) is routed through headroom's proxy the
    # same way Claude Code is, via the `/v1`-suffixed bootstrap plugin above —
    # order matters: it must load before the ex-machina auth plugin so
    # `ANTHROPIC_BASE_URL` is already set when that plugin's `rewriteUrl()`
    # first reads it.
    #
    # The "openai" provider (ChatGPT OAuth) doesn't honor config/env
    # overrides at all (see the transport-plugin comment above), so it's
    # routed instead via headroom's runtime-level transport plugin — same
    # ordering requirement, this time against the proxy-URL bootstrap plugin.
    programs.opencode.settings.plugin = mkIf config.${namespace}.opencode.enable [
      "${headroomOpencodeAnthropicBaseUrlPlugin}"
      "${headroomOpencodeProxyUrlPlugin}"
      "${headroomOpencodeTransportPlugin}"
    ];
  };
}
