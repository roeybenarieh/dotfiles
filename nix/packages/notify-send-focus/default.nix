{ pkgs, ... }:

# Generic notify-send wrapper: walks up the process tree from wherever it's
# called (through the caller, its shell, etc.) to find the nearest ancestor
# PID that Hyprland recognizes as a window owner — i.e. the actual window
# this notification originated from, regardless of whatever window happens
# to be focused by the time the user clicks it. Focuses that window back if
# the notification body is clicked — the freedesktop spec's reserved
# "default" action, which wayle's notification popups already wire up to a
# body click. Doesn't know or care which app/window called it, so it's
# reusable by any caller (Claude Code, Codex, or anything else that shells
# out to notify-send).
pkgs.writeShellApplication {
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
}
