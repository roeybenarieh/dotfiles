{ namespace, lib, config, pkgs, inputs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.opencode;

  # addyosmani/agent-skills: the 25 lifecycle skills under skills/. Each
  # directory is a self-contained SKILL.md, so mapping every directory into
  # programs.opencode.skills is the documented OpenCode install path
  # (docs/opencode-setup.md). Pinned to a commit.
  agentSkillsSrc = pkgs.fetchFromGitHub {
    owner = "addyosmani";
    repo = "agent-skills";
    rev = "301b02b12bff98e4688e6984af6556802322bbde";
    hash = "sha256-ewVxgb5GqtUeWcGydFz3GbzUkM0p+cuRfP+tlPAg4PY=";
  };
  agentSkills = mapAttrs (name: _: "${agentSkillsSrc}/skills/${name}")
    (filterAttrs (_: type: type == "directory")
      (builtins.readDir "${agentSkillsSrc}/skills"));

  # llm-agents.nix ships OpenCode 2.x as `bin/opencode2` (so it can coexist
  # with its 1.x `opencode` package), but upstream's binary is `opencode` and
  # omnigent's opencode-native harness resolves only that name
  # (shutil.which("opencode"), no override). Add the `opencode` alias.
  # version/passthru/meta are kept because home-manager's opencode module reads
  # them (getVersion, passthru.jsonschema, meta.mainProgram for wrapProgram).
  # Tracks llm-agents' latest 2.x; omnigent's <2.1 version cap is lifted in
  # nix/packages/omnigent.
  opencode2 = inputs.llm-agents-nix.packages.${pkgs.stdenv.hostPlatform.system}.opencode2;
  # `cfg.environment` is baked into the wrapper (not a session variable) so it
  # reaches every launch path, including omnigent's `opencode serve`.
  opencodePackage = pkgs.symlinkJoin {
    name = "opencode2-${opencode2.version}";
    inherit (opencode2) version passthru meta;
    paths = [ opencode2 ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm $out/bin/opencode2
      makeWrapper ${opencode2}/bin/opencode2 $out/bin/opencode2 \
        ${concatStringsSep " " (mapAttrsToList (n: v: "--set ${escapeShellArg n} ${escapeShellArg v}") cfg.environment)}
      ln -s $out/bin/opencode2 $out/bin/opencode
    '';
  };

  # ---------------------------------------------------------------------------
  # Plugins. Every plugin is built into the Nix store and loaded by absolute
  # path, so OpenCode never installs anything from npm at runtime: versions and
  # hashes live here, and `opencode plugin add/update` is never needed.
  #
  # OpenCode 2 only loads a local plugin from a DIRECTORY (a file path is
  # skipped with "configured plugin path must be a directory"), resolving
  # <dir>/server.js (or index.js) for the server, <dir>/tui.js for the TUI and
  # <dir>/rpc.js for RPC. Imports of @opencode/plugin, @opentui/*, solid-js and
  # effect are served by OpenCode itself; any other dependency has to sit in
  # the plugin's own node_modules.
  # ---------------------------------------------------------------------------
  npmTarball = name: version: hash: pkgs.fetchurl {
    url = "https://registry.npmjs.org/${name}/-/${baseNameOf name}-${version}.tgz";
    inherit hash;
  };

  # An npm package unpacked into $out, its runtime deps (attrset of
  # "<package name>" = tarball) unpacked into $out/node_modules.
  mkNpmPlugin = { name, src, deps ? { } }: pkgs.runCommand name { } ''
    mkdir -p $out
    tar xzf ${src} -C $out --strip-components=1
    ${concatStringsSep "\n" (mapAttrsToList (dep: tarball: ''
      mkdir -p $out/node_modules/${dep}
      tar xzf ${tarball} -C $out/node_modules/${dep} --strip-components=1
    '') deps)}
  '';

  # Claude Pro/Max OAuth. The v2 line is published under npm's `next` tag (the
  # 1.x `latest` line does not load in OpenCode 2). Bundled except for these two
  # imports; @opencode/plugin comes from OpenCode.
  anthropicAuthPlugin = mkNpmPlugin {
    name = "opencode-anthropic-auth";
    src = npmTarball "@ex-machina/opencode-anthropic-auth" "2.0.0-next.8" "sha256-mqd+WUlmf1CQOdtZMhFr3r3k239KJXCzyIfCDofb4hA=";
    deps."@streamparser/json" = npmTarball "@streamparser/json" "0.0.26" "sha256-ForcOF9UUvCU4tnyrHIbz8++WDoGI4M2QHcqZoiu72Y=";
  };

  # Subscription quota (ChatGPT, Claude) in the TUI sidebar and status line.
  # v6 is the OpenCode 2 line (needs >= 2.0.26); one entry loads its server,
  # TUI and RPC parts from dist/.
  quotaPlugin = mkNpmPlugin {
    name = "opencode-quota";
    src = npmTarball "@slkiser/opencode-quota" "6.3.0" "sha256-jFzIYy7PAqG4GrlR+r0/bGuzKB4/r84ri/RUK2F9S9Y=";
    deps = {
      "jsonc-parser" = npmTarball "jsonc-parser" "3.3.1" "sha256-SgMVuGcedGO65698FCzfGemqe6Oes23C3zg7hkjjy8k=";
      "@opentelemetry/api" = npmTarball "@opentelemetry/api" "1.9.1" "sha256-EeKvrkd1rNI+c89KExo5XSGY6uO93e0XciD72rlnPNI=";
    };
  };

  # opencode-auto-router only ships a 1.x plugin; ./plugins/auto-router is a
  # small 2.x adapter around the package's own routing logic (see server.js).
  autoRouterPlugin = pkgs.runCommand "opencode-auto-router-v2" { } ''
    mkdir -p $out/node_modules/opencode-auto-router
    cp ${./plugins/auto-router/server.js} $out/server.js
    cp ${./plugins/auto-router/package.json} $out/package.json
    tar xzf ${npmTarball "opencode-auto-router" "0.1.4" "sha256-V9KSXeeaZDz3Pr6deBFxjQML8TPYGBJEhBUESE356R8="} \
      -C $out/node_modules/opencode-auto-router --strip-components=1
  '';

  # @smart-coders-hq/opencode-model-fallback only ships a 1.x plugin and is
  # unmaintained; ./plugins/model-fallback is a 2.x port (no dependencies).
  modelFallbackPlugin = ./plugins/model-fallback;

  # Router tiers. Routing is per SESSION: `pinSession` locks the tier chosen by
  # the first prompt, so a trivial first prompt ("hi") pins the whole session
  # to Haiku - pick another model by hand to escape. Classifier is the default
  # keyword heuristic (<1ms, no extra deps). Per-tier `fallbacks` are
  # intentionally omitted: model-fallback handles errors. Model ids/variants
  # verified with `opencode models <provider> --verbose`.
  autoRouterOptions = {
    enabled = true;
    notify = true; # logs "[auto-router] ... -> model (variant)" per decision
    routers = [
      {
        name = "main"; # selected as `auto-router/main`
        pinSession = true;
        tierModels = {
          SIMPLE = {
            model = "anthropic/claude-haiku-5-5";
            variant = "low";
          };
          MEDIUM = {
            model = "openai/gpt-6.1-terra";
            variant = "medium";
          };
          COMPLEX = {
            model = "openai/gpt-6.1-sol";
            variant = "high";
          };
          # this would burn my tokens in no-time
          # REASONING = {
          #   model = "anthropic/claude-opus-5-5";
          #   variant = "xhigh";
          # };
        };
      }
    ];
  };

  # Ordered chain: primary (the session's model) -> sonnet -> gpt-6.1-terra.
  # A rate-limited/out-of-quota model stays unhealthy for cooldownMs (5h) and is
  # skipped until then; retryOriginalAfterMs returns to the primary after the
  # same window. Output goes to OpenCode's log (~/.local/share/opencode/log).
  modelFallbackOptions = {
    enabled = true;
    defaults = {
      fallbackOn = [ "rate_limit" "quota_exceeded" "5xx" "timeout" "overloaded" ];
      cooldownMs = 18000000;
      retryOriginalAfterMs = 18000000;
      maxFallbackDepth = 3;
    };
    agents."*".fallbackModels = [ "anthropic/claude-sonnet-5-5" "openai/gpt-6.1-terra" ];
    logging = true;
  };

in
{
  options.${namespace}.opencode = {
    enable = mkBoolOpt false "Whether or not to enable OpenCode.";
    environment = mkOpt (types.attrsOf types.str) { } "Environment variables set in OpenCode's wrapper.";
    server = {
      enable = mkBoolOpt false "Run `opencode serve` as a user service so other machines (OpenCode Manager) can attach to this machine's OpenCode instances over the tailnet.";
      port = mkOpt types.port 4096 "Port `opencode serve` listens on. The NixOS side opens it on the Tailscale interface only.";
      environmentFile = mkOpt types.str "${config.xdg.configHome}/opencode-serve/env" "Runtime file with OPENCODE_SERVER_PASSWORD. Never stored in the Nix store.";
    };
  };

  config = mkIf cfg.enable {
    systemd.user.services.opencode-serve = mkIf cfg.server.enable {
      Unit = {
        Description = "OpenCode server for remote attach";
        Wants = "network-online.target";
        After = "network-online.target";
      };
      Service = {
        ExecStart = "${opencodePackage}/bin/opencode serve --hostname 0.0.0.0 --port ${toString cfg.server.port}";
        EnvironmentFile = cfg.server.environmentFile;
        Restart = "on-failure";
        RestartSec = 10;
      };
      Install.WantedBy = [ "default.target" ];
    };

    programs.opencode = {
      enable = true;
      # nixpkgs' 1.18.30 crashes during system-prompt assembly (upstream #50439).
      package = opencodePackage;
      enableMcpIntegration = true;
      # Automatically approve TUI permission requests, as with --auto.
      cli.session.permissions = "autoaccept";
      # Global context, written to ~/.config/opencode/AGENTS.md.
      context = ''
        # Global instructions

        ## Missing programs

        If a program isn't installed, NEVER give up or ask me to install it. Run it through a Nix shell:

        - Single command: `nix shell nixpkgs#<pkg> -c <command> <args>`
        - Look up the attribute name first with the nixos MCP tool if unsure (`nix search nixpkgs <name>` or the `nix` tool, source nixos).
        - If the pure shell fails (missing host libraries, GUI/GPU access, `/etc` or `$HOME` lookups, etc.), fall back to an impure one: `nix shell --impure nixpkgs#<pkg> -c <command>`, or `nix run --impure nixpkgs#<pkg> -- <args>`.
        - For several tools at once, list them all in one shell: `nix shell nixpkgs#jq nixpkgs#ripgrep -c ...`.
      '';
      skills = agentSkills // {
        git-commit = ./skills/git-commit;
        git-pr = ./skills/git-pr;
        git-conflicts = ./skills/git-conflicts;
      };
      # OpenCode 2 config keys (plugins/providers/agents/permissions/policies).
      # The `mcp` (enableMcpIntegration) and `lsp` (extra.lsp) blocks other
      # modules add are still 1.x-shaped; OpenCode 2 accepts them in the
      # same file and lifts `mcp` under `mcp.servers` itself.
      settings = {
        # Load order matters: the auth plugin before anything that sends
        # requests; the router before model-fallback (fallback acts on the
        # concrete model the router picked). extra.mcp prepends headroom's
        # transport plugin (mkBefore) to this list.
        plugins = [
          "${anthropicAuthPlugin}/dist"
          "${quotaPlugin}/dist"
          {
            package = "${autoRouterPlugin}";
            options = autoRouterOptions;
          }
          {
            package = "${modelFallbackPlugin}";
            options = modelFallbackOptions;
          }
        ];
        # Pseudo-model: the auto-router plugin swaps it for a real tier model
        # on the first prompt of each session. Pick any real model by hand to
        # bypass routing. Real providers still need `/connect` (Anthropic) and
        # ChatGPT login for OpenAI.
        websearch.provider = "random";
        model = "auto-router/main";
        agents = {
          # Built-in subagents (task tool) inherit their parent's model unless
          # set here, so a hand-picked parent would hand them a fixed model.
          # Pin them to the router so each subagent gets its own tier decision.
          general.model = "auto-router/main";
          explore.model = "auto-router/main";
          # Title generation defaults to OpenCode Zen's hosted model (provider
          # "opencode"), a separate paid gateway with its own (unfunded) balance
          # that fails every session with "Insufficient account funds". Use the
          # subscription-backed Anthropic provider instead. (1.x `small_model`.)
          title.model = "anthropic/claude-haiku-4-5";
        };
        # Hide OpenCode Zen entirely - it lists Claude models under the same
        # names as the "anthropic" provider but bills against its own balance.
        # (1.x `disabled_providers` / empty `whitelist`.)
        policies = [
          {
            action = "provider.use";
            resource = "opencode";
            effect = "deny";
          }
        ];
        providers = {
          # Registers the `auto-router/main` pseudo-model selected above. The
          # plugin swaps the model before any request is built, so the URL is
          # never used - but OpenCode 2 refuses to initialize a model whose
          # provider has no baseURL ("requires an endpoint baseURL"), which
          # 1.x did not. Port 9 (discard) makes any accidental use fail fast.
          # Limits are the minimum across the tier models.
          auto-router = {
            package = "aisdk:@ai-sdk/openai-compatible";
            settings.baseURL = "http://127.0.0.1:9/auto-router-unused";
            models.main = {
              name = "Auto Router (haiku/terra/sol tiers)";
              limit = {
                context = 1000000;
                output = 128000;
              };
            };
          };
        };
        # Auto-approve everything (shell, edit, webfetch, MCP tools, ...) -
        # OpenCode's equivalent of Claude Code's bypassPermissions mode.
        # (`omni opencode` sessions use omnigent's own ask-all rule instead,
        # answered by its policy forwarder.)
        permissions = [
          {
            action = "*";
            resource = "*";
            effect = "allow";
          }
        ];
        # Max subagent nesting depth (default 1 = subagents cannot spawn
        # subagents). 1.x top-level `subagent_depth`.
        experimental.subagent_depth = 3;
      };
    };

    # Quota plugin settings (v6 schema: dist/settings/schema.js). Every
    # provider is shown unless listed in `providers.off`. v6 also writes this
    # file from /quota_settings; as a Nix store symlink it is read-only, so
    # change settings here rather than in the TUI.
    xdg.configFile."opencode/opencode-quota/settings.jsonc".text = builtins.toJSON {
      sidebar.show = true;
      statusLine.show = true;
      toast.show = false;
    };

    # Required by the OpenCode Neovim plugin.
    programs.neovim.extraPackages = [ pkgs.lsof ];
  };
}
