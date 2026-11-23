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

  # headroom's OpenCode transport plugin, taken straight out of the
  # `headroom-ai` PyPI wheel (same package that provides the MCP server and
  # proxy above) so it is pinned here instead of read from the mutable
  # `~/.cache/uv` copy. It routes every provider's model requests through the
  # proxy (rewriting model baseURLs via ctx.model.transform and patching the
  # Node transport for anything that bypasses them, tagging the real upstream
  # in `x-headroom-base-url`), which covers both the Anthropic (Claude Pro/Max
  # OAuth) and OpenAI (ChatGPT OAuth) providers. The proxy URL is passed as the
  # plugin's `proxyUrl` option (it would otherwise default to localhost:8787).
  #
  # 0.44 ships `_dist/index.js` exporting both the OpenCode 1.x `server` and the
  # 2.x `setup` entry points. OpenCode 2 only loads a local plugin from a
  # directory, so it is unpacked into one.
  headroomOpencodeWheel = pkgs.fetchurl {
    url = "https://files.pythonhosted.org/packages/8f/63/39c8f6bd317714bc6a68775be5da5e15bca9e91d5f95e259bc00e6de6f7f/headroom_ai-0.44.0-cp310-abi3-manylinux_2_28_x86_64.whl";
    hash = "sha256-O1x/0onn0ifc2biWYVVB6p09NziL2XsyV/yHacS373A=";
  };
  headroomOpencodePlugin = pkgs.runCommand "headroom-opencode-plugin" { } ''
    mkdir -p $out
    ${lib.getExe' pkgs.unzip "unzip"} -p ${headroomOpencodeWheel} headroom/providers/opencode/_dist/index.js > $out/index.js
    echo '{"name":"headroom-opencode","private":true,"type":"module"}' > $out/package.json
  '';
in
{
  options.${namespace}.mcp = with types; {
    enable = mkBoolOpt false "Enable the shared MCP (Model Context Protocol) server registry, consumed by AI coding harnesses (Claude Code, Codex, ...) via their `enableMcpIntegration` option.";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.nodejs pkgs.uv ]; # needed for some locally configured mcps 

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
          # OpenCode advertises headroom_retrieve itself. Server-side
          # retrieval handling can turn streaming Responses into JSON
          # requests, which OpenAI OAuth rejects.
          "HEADROOM_NO_CCR_RESPONSE_HANDLING=1"
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

    # Route OpenCode's model traffic through the headroom proxy (see
    # headroomOpencodePlugin above). mkBefore: load it ahead of extra.opencode's
    # plugins so its transport is in place before any of them sends requests.
    #
    # @ex-machina/opencode-anthropic-auth only attaches the Claude Pro/Max OAuth
    # token to https://api.anthropic.com or the origin in ANTHROPIC_BASE_URL;
    # anything else fails with "Refusing to send Anthropic OAuth credentials
    # to an untrusted origin". Name the proxy as that origin.
    ${namespace}.opencode.environment = mkIf config.${namespace}.opencode.enable {
      ANTHROPIC_BASE_URL = "http://127.0.0.1:${toString headroomProxyPort}";
    };
    programs.opencode.settings.plugins = mkIf config.${namespace}.opencode.enable (mkBefore [
      {
        package = "${headroomOpencodePlugin}";
        options.proxyUrl = "http://127.0.0.1:${toString headroomProxyPort}";
      }
    ]);
  };
}
