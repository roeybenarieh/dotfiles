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

  graphifySrc = pkgs.fetchFromGitHub {
    owner = "Graphify-Labs";
    repo = "graphify";
    rev = "09a34ad87a6c522757da1bfb8c2c209e523a4e55"; # v0.9.37
    hash = "sha256-uD6NEFL2ky5e60RKjl20+gYUHtMjABPoABmZ63vT/SM=";
  };

  # Anthropic's official skills repo
  anthropicSkillsSrc = pkgs.fetchFromGitHub {
    owner = "anthropics";
    repo = "skills";
    rev = "34040c9c568585f6929bedeaad110ad08f079624";
    hash = "sha256-tI4bTTBfI1ylltklGyiyA7pLoKXEWtrT6lrmwrpLbCw=";
  };

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
    # When OmniRoute is active, use its auto-routing model ID; otherwise use the direct Anthropic model.
    model = if cfg.omniroute.enable then "auto/claude-sonnet" else "claude-sonnet-4-6";
    theme = "dark-ansi";
    voiceEnabled = true;
    skipDangerousModePermissionPrompt = true;
    enabledPlugins = {
      "pyright-lsp@claude-plugins-official" = true;
      "context7@claude-plugins-official" = true;
      "lua-lsp@claude-plugins-official" = true;
    };
    permissions.allow = [
      "mcp__plugin_context7_context7__resolve-library-id"
      "mcp__plugin_context7_context7__query-docs"
      "WebFetch" "WebSearch" "Read" "Glob" "Grep"
      "Bash(ls:*)" "Bash(tree:*)" "Bash(cat:*)" "Bash(head:*)" "Bash(tail:*)"
      "Bash(grep:*)" "Bash(rg:*)" "Bash(find:*)" "Bash(pwd:*)" "Bash(echo:*)"
      "Bash(which:*)" "Bash(whereis:*)" "Bash(file:*)" "Bash(stat:*)"
      "Bash(du:*)" "Bash(df:*)" "Bash(wc:*)" "Bash(sort:*)" "Bash(uniq:*)"
      "Bash(diff:*)" "Bash(less:*)" "Bash(more:*)" "Bash(env:*)"
      "Bash(printenv:*)" "Bash(uname:*)" "Bash(hostname:*)" "Bash(date:*)"
      "Bash(whoami:*)" "Bash(id:*)" "Bash(mkdir:*)" "Bash(touch:*)"
      "Bash(ps:*)" "Bash(top:*)" "Bash(uptime:*)" "Bash(history:*)"
      "Bash(type:*)" "Bash(command:*)" "Bash(realpath:*)" "Bash(readlink:*)"
      "Bash(basename:*)" "Bash(dirname:*)"
      "Bash(git status:*)" "Bash(git log:*)" "Bash(git diff:*)" "Bash(git show:*)"
      "Bash(git branch:*)" "Bash(git branch -a:*)" "Bash(git branch -r:*)"
      "Bash(git branch -l:*)" "Bash(git branch --list:*)" "Bash(git remote:*)"
      "Bash(git remote -v:*)" "Bash(git remote show:*)" "Bash(git config --list:*)"
      "Bash(git config --get:*)" "Bash(git ls-files:*)" "Bash(git ls-tree:*)"
      "Bash(git ls-remote:*)" "Bash(git reflog:*)" "Bash(git describe:*)"
      "Bash(git rev-parse:*)" "Bash(git rev-list:*)" "Bash(git shortlog:*)"
      "Bash(git blame:*)" "Bash(git annotate:*)" "Bash(git grep:*)"
      "Bash(git show-branch:*)" "Bash(git whatchanged:*)" "Bash(git cherry:*)"
      "Bash(git tag:*)" "Bash(git tag -l:*)" "Bash(git tag --list:*)"
      "Bash(git fetch:*)" "Bash(git cat-file:*)" "Bash(git merge-base:*)"
      "Bash(git name-rev:*)" "Bash(git for-each-ref:*)" "Bash(git show-ref:*)"
      "Bash(git verify-commit:*)" "Bash(git verify-tag:*)" "Bash(git symbolic-ref:*)"
      "Bash(git count-objects:*)" "Bash(git fsck:*)" "Bash(git check-ignore:*)"
      "Bash(git check-attr:*)" "Bash(git check-ref-format:*)"
      "Bash(fastapi:*)" "Bash(uv:*)" "Bash(pip:*)" "Bash(pip3:*)"
      "Bash(python:*)" "Bash(python3:*)" "Bash(curl:*)" "Bash(wget:*)"
      "Bash(sleep:*)" "Bash(cd:*)" "Bash(poetry:*)" "Bash(jq:*)" "Bash(yq:*)"
      "Bash(awk:*)" "Bash(sed:*)" "Bash(cut:*)" "Bash(paste:*)" "Bash(tr:*)"
      "Bash(column:*)" "Bash(lsblk:*)" "Bash(lscpu:*)" "Bash(lsusb:*)"
      "Bash(lspci:*)" "Bash(free:*)" "Bash(vmstat:*)" "Bash(ip:*)" "Bash(ss:*)"
      "Bash(pytest:*)" "Bash(jest:*)" "Bash(cargo test:*)" "Bash(go test:*)"
      "Bash(npm test:*)" "Bash(docker:*)" "Bash(npm run test:*)"
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

    home.sessionVariables = mkIf cfg.omniroute.enable {
      ANTHROPIC_BASE_URL = "http://localhost:${toString cfg.omniroute.port}/v1";
    };

    # TODO: you programs.claude-code instead
    home.packages = with pkgs; [
      claude-desktop-fhs # claude desktop app
      claude-code # cli
      sox # for using voice
      # MCP related
      nodejs # needed for some MCPs
      pyright # needed in non-pycharm environments for python analytics using LSP
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

    # task-observer meta-skill: watches sessions and improves the skill library over time
    home.file.".claude/skills/task-observer/SKILL.md".source = "${taskObserverSrc}/SKILL.md";
    home.file.".claude/skills/task-observer/references/environments.md".source = "${taskObserverSrc}/references/environments.md";
    home.file.".claude/skills/task-observer/references/skill-authoring.md".source = "${taskObserverSrc}/references/skill-authoring.md";
    home.file.".claude/skills/task-observer/references/weekly-review.md".source = "${taskObserverSrc}/references/weekly-review.md";

    # skill-creator: Anthropic's official skill for authoring/packaging new skills
    home.file.".claude/skills/skill-creator".source = "${skillCreatorSrc}/skills/skill-creator";
    # pdf: Anthropic's official skill for reading/extracting, merging/splitting,
    # creating, filling forms in, and OCR'ing PDF files
    home.file.".claude/skills/pdf".source = "${anthropicSkillsSrc}/skills/pdf";

    # graphify: maps any codebase into a queryable knowledge graph
    home.file.".claude/skills/graphify/SKILL.md".source = "${graphifySrc}/graphify/skill.md";
    home.file.".claude/skills/graphify/references/add-watch.md".source = "${graphifySrc}/graphify/skills/claude/references/add-watch.md";
    home.file.".claude/skills/graphify/references/exports.md".source = "${graphifySrc}/graphify/skills/claude/references/exports.md";
    home.file.".claude/skills/graphify/references/extraction-spec.md".source = "${graphifySrc}/graphify/skills/claude/references/extraction-spec.md";
    home.file.".claude/skills/graphify/references/github-and-merge.md".source = "${graphifySrc}/graphify/skills/claude/references/github-and-merge.md";
    home.file.".claude/skills/graphify/references/hooks.md".source = "${graphifySrc}/graphify/skills/claude/references/hooks.md";
    home.file.".claude/skills/graphify/references/query.md".source = "${graphifySrc}/graphify/skills/claude/references/query.md";
    home.file.".claude/skills/graphify/references/transcribe.md".source = "${graphifySrc}/graphify/skills/claude/references/transcribe.md";
    home.file.".claude/skills/graphify/references/update.md".source = "${graphifySrc}/graphify/skills/claude/references/update.md";
    home.file.".claude/CLAUDE.md".text = ''
      # graphify
      - **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
      When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.

      ## Proactive graphify use

      Before answering any question about a codebase — architecture, structure, file relationships, data flow, "how does X work", "what calls Y", "trace Z", "what modules exist", "explain the design" — check whether `graphify-out/graph.json` exists in the current working directory. If it does, treat the question as a graphify query first: invoke the graphify skill and run `graphify query "<question>"` rather than relying on file reads alone.

      Also consider invoking graphify (full pipeline or query) when:
      - The user asks a broad exploratory question that would benefit from cross-file relationship knowledge
      - The user asks to map, summarise, or visualise the project structure
      - A task requires understanding many files at once (e.g. a large refactor, dependency analysis)
      - `graphify-out/` exists: always prefer it for codebase questions over ad-hoc file reading

      If `graphify-out/graph.json` does NOT exist and the question is clearly architectural/structural, consider suggesting to the user that running `/graphify` first would give better answers — but do not block on it; proceed with file reading if they prefer.
    '';

    home.file.".claude/settings.json" = {
      force = true; # file exists as a mutable file; Nix now owns it
      text = builtins.toJSON claudeSettings;
    };

    programs.chromium = {
      extensions = [ "fcoeoabgfenejglbffodgkkbkcdhcgfn" ]; # claude chrome extension
      commandLineArgs = [
        "--remote-debugging-port=9222" # enable Chrome's remote debugging API - used by claude sometimes
      ];
    };
  };
}
