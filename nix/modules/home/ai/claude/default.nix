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

  # Generic notify-send wrapper: walks up the process tree from wherever it's
  # called (through the caller, its shell, etc.) to find the nearest ancestor
  # PID that Hyprland recognizes as a window owner — i.e. the actual window
  # this notification originated from, regardless of whatever window happens
  # to be focused by the time the user clicks it. Focuses that window back if
  # the notification body is clicked — the freedesktop spec's reserved
  # "default" action, which wayle's notification popups already wire up to a
  # body click. Doesn't know or care which app/window called it, so it's
  # reusable beyond claude too.
  notifySendFocusScript = pkgs.writeShellApplication {
    name = "notify-send-focus";
    runtimeInputs = [ pkgs.libnotify pkgs.hyprland pkgs.jq pkgs.glib ];
    text = ''
      find_window_addr() {
        local pid="$1" ppid clients addr

        clients=$(hyprctl clients -j) || return 1

        while [ "$pid" -gt 1 ] 2>/dev/null; do
          addr=$(printf '%s' "$clients" | jq -r --argjson pid "$pid" \
            '.[] | select(.pid == $pid) | .address' 2>/dev/null | head -n1)
          if [ -n "$addr" ]; then
            printf '%s\n' "$addr"
            return 0
          fi

          ppid=$(awk '/^PPid:/ {print $2}' "/proc/$pid/status" 2>/dev/null) || return 1
          [ -n "$ppid" ] || return 1
          pid="$ppid"
        done

        return 1
      }

      addr=""
      if resolved=$(find_window_addr "$$"); then
        addr="$resolved"
      fi

      if [ -z "$addr" ]; then
        exec notify-send "$@"
      fi

      # Minimal notify-send-alike arg parsing: -u/--urgency is accepted but
      # dropped ("normal" is the freedesktop-spec default anyway), the rest is
      # SUMMARY [BODY]. Keep the originals around too, since this loop
      # consumes "$@" and the notify-send fallback below still needs it.
      orig_args=("$@")
      summary=""
      body=""
      while [ "$#" -gt 0 ]; do
        case "$1" in
          -u | --urgency) shift 2 ;;
          *)
            if [ -z "$summary" ]; then
              summary="$1"
            elif [ -z "$body" ]; then
              body="$1"
            fi
            shift
            ;;
        esac
      done

      # notify-send's own -w/-A wait mode blocks until the server sends
      # NotificationClosed — but wayle doesn't reliably emit that (dismissing
      # a popup just hides it from the toast tray while keeping it in
      # history), so notify-send -w hangs forever regardless of whether the
      # notification was ever clicked. So: send the notification directly
      # over D-Bus and listen for the ActionInvoked signal ourselves instead,
      # bounded by a timeout, rather than trusting notify-send to report back.
      # The "--" is required: gdbus otherwise parses a bare "-1" as an
      # (unrecognized) option rather than the expire_timeout value.
      id_raw=$(gdbus call --session \
        --dest org.freedesktop.Notifications \
        --object-path /org/freedesktop/Notifications \
        --method org.freedesktop.Notifications.Notify \
        -- "" 0 "" "$summary" "$body" "['default','default']" "{}" -1) \
        || exec notify-send "''${orig_args[@]}"
      # gdbus prints "(uint32 1860,)" — a plain [0-9]+ grep would match the
      # "32" inside the word "uint32" itself before the real id, so anchor on
      # the actual tuple shape instead.
      id=$(printf '%s' "$id_raw" | sed -n 's/^(uint32 \([0-9]*\),)$/\1/p')
      [ -n "$id" ] || exit 0

      coproc MON { gdbus monitor --session --dest org.freedesktop.Notifications 2>/dev/null; }

      deadline=$((SECONDS + 60))
      clicked=0
      while [ "$SECONDS" -lt "$deadline" ]; do
        if read -r -t 1 -u "''${MON[0]}" line; then
          case "$line" in
            *"ActionInvoked (uint32 $id, 'default')"*)
              clicked=1
              break
              ;;
          esac
        fi
      done

      kill "$MON_PID" 2>/dev/null || true
      wait "$MON_PID" 2>/dev/null || true

      if [ "$clicked" = "1" ]; then
        # On this Hyprland version, "dispatch focuswindow address:..." (the
        # classic CLI syntax) fails — dispatch commands are evaluated through
        # its Lua layer, and hl.dsp.focus's `window` field must be an actual
        # window object from hl.get_windows(), not an address string.
        hyprctl repl "local wins = hl.get_windows(); for _, w in ipairs(wins) do if w.address == \"$addr\" then hl.dispatch(hl.dsp.focus({ window = w })) end end" >/dev/null 2>&1 || true
      fi
    '';
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
    theme = "dark-ansi";
    tui = "fullscreen";
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
            command = "${pkgs.jq}/bin/jq -r '.message // \"Claude needs your attention\"' | { read -r msg; ${notifySendFocusScript}/bin/notify-send-focus -u normal \"Claude Code\" \"$msg\"; }";
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
    home.shellAliases = {
      claude = "claude --permission-mode auto";
    } // optionalAttrs cfg.litellm.enable {
      claudefree = "ANTHROPIC_BASE_URL=http://localhost:${toString cfg.litellm.port} ANTHROPIC_AUTH_TOKEN=${cfg.litellm.masterKey} ANTHROPIC_API_KEY='' claude --permission-mode auto";
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
        nix = {
          command = "${pkgs.nixd}/bin/nixd";
          args = [ ];
          extensionToLanguage = {
            ".nix" = "nix";
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
        "--silent-debugger-extension-api" # suppress the "started debugging this browser" infobar from the claude extension's use of chrome.debugger
      ];
    };
  };
}
