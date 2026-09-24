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
    runtimeInputs = [ pkgs.jq pkgs.procps pkgs.gawk ];
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

      MEM_PCT=$(free | awk '/^Mem:/ {printf "%d", $3/$2*100}')
      CPU_LOAD=$(awk '{print $1}' /proc/loadavg)

      CYAN=$'\033[36m'
      GREEN=$'\033[32m'
      YELLOW=$'\033[33m'
      RED=$'\033[31m'
      RESET=$'\033[0m'

      if [ "$PCT" -lt 50 ]; then
        CTX_COLOR="$GREEN"
      elif [ "$PCT" -lt 80 ]; then
        CTX_COLOR="$YELLOW"
      else
        CTX_COLOR="$RED"
      fi

      printf '%s[%s]%s %s | %s%d%%%s ctx | %s tok | $%.3f | mem %d%% | cpu %s\n' \
        "$CYAN" "$MODEL" "$RESET" \
        "$DIR_NAME" \
        "$CTX_COLOR" "$PCT" "$RESET" \
        "$TOKENS" \
        "$COST" \
        "$MEM_PCT" \
        "$CPU_LOAD"
    '';
  };

  claudeSettings = {
    attribution = { commit = ""; pr = ""; };
    theme = "dark-ansi";
    voiceEnabled = true;
    skipDangerousModePermissionPrompt = true;
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
            command = "${pkgs.jq}/bin/jq -r '.message // \"Claude needs your attention\"' | { read -r msg; ${pkgs.libnotify}/bin/notify-send -u normal \"Claude Code\" \"$msg\"; }";
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
    };
  };

  config = mkIf cfg.enable {
    home.shellAliases.claude = "claude --permission-mode auto";

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

      mcpServers = {
        context7 = {
          type = "http";
          url = "https://mcp.context7.com/mcp?client=claude-code-nix";
          headers = {
            Authorization = "\${CONTEXT7_API_KEY:-}";
          };
        };
        headroom = {
          type = "stdio";
          command = "uvx";
          args = [ "--from" "headroom-ai" "headroom" "mcp" "serve" ];
        };
        serena = {
          type = "stdio";
          command = "uvx";
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
        };
      };

      lspServers = {
        python = {
          command = "${pkgs.pyright}/bin/pyright-langserver";
          args = [ "--stdio" ];
          extensionToLanguage = {
            ".py" = "python";
            ".pyi" = "python";
          };
        };
        lua = {
          command = "${pkgs.lua-language-server}/bin/lua-language-server";
          args = [ ];
          extensionToLanguage = {
            ".lua" = "lua";
          };
        };
      };

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
      };

      context = ''
        ## Git commits
        Never run `git commit` unless the user explicitly asks you to commit. Stage files, make changes, and tell the user what's ready — but do not commit on your own initiative.

        ## LSP servers
        LSP servers are available via the `LSP` tool for Python, Lua, and Nix. Prefer it over grep for navigation (definitions, references, diagnostics) in those languages.
      '';
    };

    programs.chromium = {
      extensions = [ "fcoeoabgfenejglbffodgkkbkcdhcgfn" ]; # claude chrome extension
      commandLineArgs = [
        "--remote-debugging-port=9222" # enable Chrome's remote debugging API - used by claude sometimes
      ];
    };
  };
}
