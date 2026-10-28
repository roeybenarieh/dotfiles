{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.claude;

  taskObserverSrc = pkgs.fetchFromGitHub {
    owner = "rebelytics";
    repo = "one-skill-to-rule-them-all";
    rev = "281f13466cd3a73e9ebc9d210907748e1941a3dd";
    hash = "sha256-VdK06HjwFWqAmFcN6xG11fH4D2gnZy91SmXVFFrmLXQ=";
  };

  # Anthropic's official skills repo
  anthropicSkillsSrc = pkgs.fetchFromGitHub {
    owner = "anthropics";
    repo = "skills";
    rev = "34040c9c568585f6929bedeaad110ad08f079624";
    hash = "sha256-tI4bTTBfI1ylltklGyiyA7pLoKXEWtrT6lrmwrpLbCw=";
  };

  graphifySrc = pkgs.fetchFromGitHub {
    owner = "Graphify-Labs";
    repo = "graphify";
    rev = "09a34ad87a6c522757da1bfb8c2c209e523a4e55"; # v0.9.37
    hash = "sha256-uD6NEFL2ky5e60RKjl20+gYUHtMjABPoABmZ63vT/SM=";
  };

  # ponytail: pushes the agent toward the simplest, dependency-light solution
  # (YAGNI, stdlib-first) instead of over-engineering. Installed as a real
  # Claude Code plugin (not just its skills) so its SessionStart/UserPromptSubmit
  # hooks fire — those hooks are what actually force the ruleset into context
  # on every turn; the skills alone are only model-invoked on a description
  # match and wouldn't give the "active every response" behavior ponytail advertises.
  ponytailSrc = pkgs.fetchFromGitHub {
    owner = "dietrichgebert";
    repo = "ponytail";
    rev = "e3ba2aa6f1e6f0bc4d69eb09c9f0d0a93af56156";
    hash = "sha256-PES5XrSYx0VBXWVHEDRykGy0SAmJfV/luzy8Gfg0aAQ=";
  };

  # taste-skill: anti-slop frontend design skill (tasteskill.dev) — reads the
  # brief, infers a design direction, and pushes frontend output away from
  # templated-looking defaults. Single-file skill, so fetch it directly
  # rather than the whole taste-skill repo.
  tasteSkillSrc = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/Leonxlnx/taste-skill/ce26fc25c0e5e8cab638f883de62d9a86ee5e45b/skills/taste-skill/SKILL.md";
    hash = "sha256-qhlDUbJGuLR5kJnU7XsDPSnqtubj1Y2NIXKXi+ez7Ik=";
  };

  # graphify's SKILL.md sits at the repo root (alongside its source code) and its
  # references live in a separate nested path, so assemble a proper skill directory
  # for programs.claude-code.skills rather than pointing at graphifySrc directly.
  graphifySkillDir = pkgs.runCommand "graphify-skill" { } ''
    mkdir -p $out/references
    cp ${graphifySrc}/graphify/skill.md $out/SKILL.md
    cp -r ${graphifySrc}/graphify/skills/claude/references/. $out/references/
  '';

  statusLineScript = pkgs.writeShellApplication {
    name = "claude-statusline";
    runtimeInputs = [ pkgs.jq pkgs.procps pkgs.gawk pkgs.coreutils ];
    text = ''
      input=$(cat)
      MODEL=$(echo "$input" | jq -r '.model.display_name // "unknown"')
      DIR=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
      DIR_NAME=$(basename "$DIR")
      PCT=$(echo "$input" | jq -r '(.context_window.used_percentage // 0) | floor')
      COST=$(echo "$input" | jq -r '(.cost.total_cost_usd // 0)')
      TOKENS=$(echo "$input" | jq -r '
        (.context_window.total_input_tokens // 0) as $t |
        if $t >= 1000 then (($t / 1000 * 10 | round) / 10 | tostring) + "k"
        else ($t | tostring)
        end')

      # Subscription usage (5-hour session window + weekly window), reported
      # by Claude Code itself — absent until it has polled the API at least once.
      FIVE_HOUR_PCT=$(echo "$input" | jq -r '(.rate_limits.five_hour.used_percentage // null) | if . != null then floor else null end')
      SEVEN_DAY_PCT=$(echo "$input" | jq -r '(.rate_limits.seven_day.used_percentage // null) | if . != null then floor else null end')
      FIVE_HOUR_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')

      MEM_PCT=$(free | awk '/^Mem:/ {printf "%d", $3/$2*100}')
      CPU_LOAD=$(awk '{print $1}' /proc/loadavg)

      CYAN=$'\033[36m'
      GREEN=$'\033[32m'
      YELLOW=$'\033[33m'
      RED=$'\033[31m'
      RESET=$'\033[0m'

      pct_color() {
        if [ "$1" -lt 50 ]; then
          echo "$GREEN"
        elif [ "$1" -lt 80 ]; then
          echo "$YELLOW"
        else
          echo "$RED"
        fi
      }

      CTX_COLOR=$(pct_color "$PCT")

      USAGE_SEGMENT=""
      if [ "$FIVE_HOUR_PCT" != "null" ]; then
        FIVE_HOUR_COLOR=$(pct_color "$FIVE_HOUR_PCT")
        RESET_IN=""
        if [ -n "$FIVE_HOUR_RESET" ]; then
          SECS_LEFT=$(( ''${FIVE_HOUR_RESET%.*} - $(date +%s) ))
          if [ "$SECS_LEFT" -gt 0 ]; then
            RESET_IN=$(printf ' (resets %dh%dm)' $((SECS_LEFT / 3600)) $(((SECS_LEFT % 3600) / 60)))
          fi
        fi
        USAGE_SEGMENT="''${USAGE_SEGMENT} | ''${FIVE_HOUR_COLOR}''${FIVE_HOUR_PCT}%''${RESET} 5h''${RESET_IN}"
      fi
      if [ "$SEVEN_DAY_PCT" != "null" ]; then
        SEVEN_DAY_COLOR=$(pct_color "$SEVEN_DAY_PCT")
        USAGE_SEGMENT="''${USAGE_SEGMENT} | ''${SEVEN_DAY_COLOR}''${SEVEN_DAY_PCT}%''${RESET} 7d"
      fi

      printf '%s[%s]%s %s | %s%d%%%s ctx | %s tok | $%.3f%s | mem %d%% | cpu %s\n' \
        "$CYAN" "$MODEL" "$RESET" \
        "$DIR_NAME" \
        "$CTX_COLOR" "$PCT" "$RESET" \
        "$TOKENS" \
        "$COST" \
        "$USAGE_SEGMENT" \
        "$MEM_PCT" \
        "$CPU_LOAD"
    '';
  };

  claudeSettings = {
    attribution = { commit = ""; pr = ""; };
    theme = "dark-ansi";
    tui = "fullscreen";
    voiceEnabled = true;
    skipDangerousModePermissionPrompt = true;
    permissions.defaultMode = "auto";
    permissions.allow = [
      "mcp__context7__resolve-library-id"
      "mcp__context7__query-docs"
      "WebFetch" "WebSearch" "Read" "Glob" "Grep"
    ];
    hooks.Notification = [
      {
        hooks = [
          {
            type = "command";
            command = "${pkgs.jq}/bin/jq -r '.message // \"Claude needs your attention\"' | { read -r msg; ${pkgs.extra.notify-send-focus}/bin/notify-send-focus -u normal \"Claude Code\" \"$msg\"; }";
            async = true;
          }
        ];
      }
    ];
  } // optionalAttrs cfg.statusLine.enable {
    statusLine = {
      type = "command";
      command = "${statusLineScript}/bin/claude-statusline";
    };
  };
in
{
  options.${namespace}.claude = with types; {
    enable = mkBoolOpt false "Whether or not to enable claude-desktop.";
    statusLine = {
      enable = mkBoolOpt false "Enable the Claude Code status line showing model, context usage, and cost.";
    };
    litellm = {
      enable = mkBoolOpt false "Route Claude Code through a local LiteLLM proxy.";
      port = mkIntOpt 4000 "LiteLLM port (must match the NixOS litellm module).";
      masterKey = mkstrOpt "sk-litellm" "LiteLLM master key — sent as ANTHROPIC_API_KEY so the proxy accepts the request.";
    };
  };

  config = mkIf cfg.enable {
    home.shellAliases = optionalAttrs cfg.litellm.enable {
      claudefree = "ANTHROPIC_BASE_URL=http://localhost:${toString cfg.litellm.port} ANTHROPIC_AUTH_TOKEN=${cfg.litellm.masterKey} ANTHROPIC_API_KEY='' claude";
    };

    home.packages = with pkgs; [
      claude-desktop-fhs # claude desktop app
      sox # for using voice
      gh # needed for interacting with github

      # "pdf" skill deps: CLI tools it shells out to (its python packages are
      # merged into languages.python's env via extraPackages, set below)
      poppler-utils # pdftotext, pdfimages
      qpdf
      pdftk
      tesseract # OCR for scanned PDFs
    ];

    # python3Packages used by the "pdf" skill's scripts (text/table extraction,
    # form filling, image rendering, OCR, xlsx export of extracted tables) —
    # merged into extra.software-development.languages.python's single shared
    # interpreter below, since Home Manager can't have two independent
    # python.withPackages closures on PATH at once
    extra.software-development.languages.python.extraPackages = [
      "pypdf"
      "pdfplumber"
      "reportlab"
      "pypdfium2"
      "pytesseract"
      "pdf2image"
      "pandas"
      "openpyxl"
    ];

    programs.claude-code = {
      enable = true;
      settings = claudeSettings;

      # Server list comes from `extra.mcp` (programs.mcp.servers) — see
      # nix/modules/home/ai/mcp/default.nix.
      enableMcpIntegration = true;

      # Native LSP settings come from extra.lsp, shared with other harnesses.

      skills = {
        # task-observer meta-skill: watches sessions and improves the skill library over time
        task-observer = taskObserverSrc;

        # skill-creator: Anthropic's official skill for authoring/packaging new skills
        skill-creator = "${anthropicSkillsSrc}/skills/skill-creator";

        # pdf: Anthropic's official skill for reading/extracting, merging/splitting,
        # creating, filling forms in, and OCR'ing PDF files
        pdf = "${anthropicSkillsSrc}/skills/pdf";

        # graphify: maps any codebase into a queryable knowledge graph
        graphify = graphifySkillDir;

        # taste-skill: anti-slop frontend design skill from tasteskill.dev
        taste-skill = tasteSkillSrc;
      };

      plugins = {
        ponytail = ponytailSrc;
      };

      context = ''
        ## Git commits
        Never run `git commit` unless the user explicitly asks you to commit. Stage files, make changes, and tell the user what's ready — but do not commit on your own initiative.
      '';
    };

    programs.chromium = {
      extensions = [ "fcoeoabgfenejglbffodgkkbkcdhcgfn" ]; # claude chrome extension
      commandLineArgs = [
        "--remote-debugging-port=9222" # enable Chrome's remote debugging API - used by claude sometimes
        "--silent-debugger-extension-api" # suppress the "started debugging this browser" infobar from the claude extension's use of chrome.debugger
      ];
    };
  };
}
