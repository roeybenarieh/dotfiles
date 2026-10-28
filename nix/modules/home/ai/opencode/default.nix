{ namespace, lib, config, pkgs, inputs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.opencode;

  # ponytail: pushes the agent toward the simplest, dependency-light solution
  # (YAGNI, stdlib-first) instead of over-engineering. OpenCode has no
  # directory-based plugin install (unlike Claude Code/Codex's `plugins`
  # option), so point straight at ponytail's own OpenCode plugin file — it
  # self-registers the bundled skills/commands AND hooks its ruleset into
  # every turn's system prompt (experimental.chat.system.transform), which is
  # what actually forces it on; just adding the skills directory wouldn't,
  # since skills are only model-invoked on a description match.
  ponytailSrc = pkgs.applyPatches {
    src = pkgs.fetchFromGitHub {
      owner = "dietrichgebert";
      repo = "ponytail";
      rev = "e3ba2aa6f1e6f0bc4d69eb09c9f0d0a93af56156";
      hash = "sha256-PES5XrSYx0VBXWVHEDRykGy0SAmJfV/luzy8Gfg0aAQ=";
    };
    # Discovery alone does not tell the agent when to invoke companion skills.
    patches = [ ./ponytail-skill-routing.patch ];
  };

in
{
  options.${namespace}.opencode = {
    enable = mkBoolOpt false "Whether or not to enable OpenCode.";
  };

  config = mkIf cfg.enable {
    programs.opencode = {
      enable = true;
      # nixpkgs' 1.18.30 crashes during system-prompt assembly (upstream #50439).
      package = inputs.llm-agents-nix.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
      enableMcpIntegration = true;
      # TUI plugins live in tui.json (OpenCode 1.2.15+). Quota shows in the sidebar panel.
      tui.plugin = [
        "@slkiser/opencode-quota@4"
      ];
      # Global context, written to ~/.config/opencode/AGENTS.md.
      context = ''
        # Global instructions

        ## Missing programs

        If you need a program that isn't installed, don't give up or ask me to install it. Run it through a Nix shell:

        - Single command: `nix shell nixpkgs#<pkg> -c <command> <args>`
        - Look up the attribute name first with the nixos MCP tool if unsure (`nix search nixpkgs <name>` or the `nix` tool, source nixos).
        - If the pure shell fails (missing host libraries, GUI/GPU access, `/etc` or `$HOME` lookups, etc.), fall back to an impure one: `nix shell --impure nixpkgs#<pkg> -c <command>`, or `nix run --impure nixpkgs#<pkg> -- <args>`.
        - For several tools at once, list them all in one shell: `nix shell nixpkgs#jq nixpkgs#ripgrep -c ...`.
      '';
      skills = {
        git-commit = ./skills/git-commit;
        git-pr = ./skills/git-pr;
        git-conflicts = ./skills/git-conflicts;
      };
      settings = {
        # Community Claude Pro/Max OAuth support for OpenCode v1.
        # Sign in with /connect -> Anthropic -> Claude Pro/Max.
        plugin = [
          # Tracks npm's `latest` tag rather than a pinned version - OpenCode
          # fetches plugins over the network at its own runtime (not via Nix),
          # so pinning here wouldn't add reproducibility anyway, just extra
          # manual version bumps.
          "@ex-machina/opencode-anthropic-auth"
          # FALLBACK DYNAMICS - read before touching either plugin below:
          #  - opencode-auto-router picks ONE model+variant per session on the
          #    first prompt (pinSession), by rewriting the user message's model
          #    in the `chat.message` hook. It only acts when the selected model
          #    is `auto-router/main`; a model picked by hand is left alone.
          #    Tiers live in opencode-auto-router.json (below).
          #  - opencode-model-fallback reacts to rate limits, quota errors, 5xx,
          #    timeouts and overload: it redirects or replays on the next model
          #    in the ordered chain (model-fallback.json, below). Failed models
          #    stay unhealthy for cooldownMs, so later prompts skip them until
          #    the cooldown ends (in-memory only, reset on restart).
          #  - The router's own per-tier `fallbacks` are deliberately UNUSED:
          #    it only records a failure and applies it on the user's NEXT
          #    prompt, so model-fallback owns all error recovery.
          #  - Fallback replays run on a concrete model, never `auto-router/main`,
          #    so the router does not interfere with them.
          "@smart-coders-hq/opencode-model-fallback"
          # Shows OpenAI (ChatGPT) and Anthropic (Claude) subscription quota in
          # the TUI (sidebar + compact status line). Pinned to v4: v5 requires
          # OpenCode 2.x, and this config uses OpenCode 1.x.
          "@slkiser/opencode-quota@4"
          "opencode-auto-router"
          "${ponytailSrc}/.opencode/plugins/ponytail.mjs"
        ];
        # Pseudo-model: opencode-auto-router swaps it for a real tier model
        # (see opencode-auto-router.json) on the first prompt of each session.
        # Pick any real model by hand to bypass routing. Real providers still
        # need `opencode auth login --provider openai` (ChatGPT) and /connect
        # for Anthropic.
        model = "auto-router/main";
        # Built-in subagents (task tool) inherit their parent's model unless
        # set here, so a hand-picked parent would hand them a fixed model.
        # Pin them to the router so each subagent gets its own tier decision.
        # Custom subagents need `model = "auto-router/main"` in their own config.
        agent = {
          general.model = "auto-router/main";
          explore.model = "auto-router/main";
        };
        # Title generation defaults to OpenCode Zen's hosted model (provider
        # "opencode"), a separate paid gateway with its own account balance -
        # distinct from the "anthropic" provider's Claude Pro/Max OAuth above,
        # despite both listing identically-named Claude models. With no funds
        # loaded in the Zen account this silently fails every session
        # ("Insufficient account funds"), so pin it to the subscription-backed
        # Anthropic provider instead.
        small_model = "anthropic/claude-haiku-4-5";
        # Hide OpenCode Zen entirely - it lists Claude models under the same
        # names as the "anthropic" provider above but bills against its own
        # (unfunded) account balance, making it easy to pick by mistake.
        # `disabled_providers` alone doesn't reach `omni opencode` sessions:
        # omnigent runs opencode-native with an isolated XDG_CONFIG_HOME and
        # only merges the `provider`/`model`/`plugin` keys back in (see
        # opencodeSharedMcpPlugin's comment in the omnigent module), so
        # `disabled_providers` is silently dropped there. An empty
        # `whitelist` on the provider itself survives that merge (it's
        # nested under `provider`) and makes opencode delete every one of
        # its models, which in turn deletes the provider outright
        # (packages/opencode/src/provider/provider.ts in anomalyco/opencode:
        # a provider left with zero models after whitelist/blacklist
        # filtering is removed from the provider list entirely).
        disabled_providers = [ "opencode" ];
        provider.opencode.whitelist = [ ];
        # Registers the `auto-router/main` pseudo-model selected above. No
        # baseURL/apiKey: the plugin swaps the model before any request is
        # built, so the URL is never used. If the plugin fails to load,
        # opencode errors with `"undefined/chat/completions" cannot be parsed
        # as a URL` - that means the router isn't active. Limits are the
        # minimum across all four tier models (all >= 1M context / 128k out).
        provider.auto-router = {
          npm = "@ai-sdk/openai-compatible";
          models.main = {
            name = "Auto Router (haiku/gpt-6-astra/sonnet/opus tiers)";
            limit = {
              context = 1000000;
              output = 128000;
            };
          };
        };
        # Auto-approve everything (shell, edit, webfetch, etc.) - OpenCode's
        # equivalent of Claude Code's bypassPermissions mode. The installed
        # package is OpenCode V1, whose config schema uses a singular
        # "permission" key (not the V2 "permissions" rule-array format),
        # which can just be the plain string "allow".
        permission = "allow";
        # Max subagent nesting depth (default 1 = subagents cannot spawn subagents).
        subagent_depth = 3;
      };
    };

    # Router tiers (see the FALLBACK DYNAMICS comment on the plugin list).
    # Routing is per SESSION: `pinSession` locks the tier chosen by the first
    # prompt, so a trivial first prompt ("hi") pins the whole session to
    # Haiku - pick another model by hand to escape, or swap pinSession for
    # `firstMessageOnly`/re-route-every-message if that bites. Classifier is
    # the default keyword heuristic (<1ms, no extra deps). Per-tier
    # `fallbacks` are intentionally omitted: model-fallback handles errors.
    # Model ids/variants verified with `opencode models <provider> --verbose`.
    xdg.configFile."opencode/opencode-auto-router.json".text = builtins.toJSON {
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
              model = "openai/gpt-6-astra";
              variant = "medium";
            };
            COMPLEX = {
              model = "anthropic/claude-sonnet-5-5";
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

    # Quota plugin settings (read from the OpenCode config dir).
    xdg.configFile."opencode/opencode-quota/quota-toast.jsonc".text = builtins.toJSON {
      enabledProviders = "auto";
      tuiSidebarPanel.enabled = true;
      tuiCompactStatus.enabled = true;
      enableToast = false;
    };

    # Ordered chain: primary (the session's model) -> sonnet -> gpt-6-astra.
    # A limited model stays unhealthy for cooldownMs (5h) and is skipped until
    # then. retryOriginalAfterMs returns to the primary after the same window.
    xdg.configFile."opencode/model-fallback.json".text = builtins.toJSON {
      enabled = true;
      defaults = {
        fallbackOn = [ "rate_limit" "quota_exceeded" "5xx" "timeout" "overloaded" ];
        cooldownMs = 18000000;
        retryOriginalAfterMs = 18000000;
        maxFallbackDepth = 3;
      };
      agents."*".fallbackModels = [ "anthropic/claude-sonnet-5-5" "openai/gpt-6-astra" ];
      logging = true;
      logLevel = "info";
      logPath = "~/.local/share/opencode/logs/model-fallback.log";
    };

    # Required by the OpenCode Neovim plugin.
    programs.neovim.extraPackages = [ pkgs.lsof ];
  };
}
