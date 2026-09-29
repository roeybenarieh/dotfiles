{ namespace, lib, config, pkgs, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktop.hyprland.clipboard;
  lua = lib.generators.mkLuaInline;
  rofi = "${config.programs.rofi.finalPackage}/bin/rofi";

  # rofi custom "mode" script for cliphist: on list, prints each history
  # entry (decoding images to temp files so rofi can show them as icons via
  # `-show-icons`); on selection (passed as $1), decodes and copies that
  # entry to the clipboard.
  #
  # Based on cliphist's own contrib/cliphist-rofi-img
  # (https://github.com/sentriz/cliphist/blob/master/contrib/cliphist-rofi-img),
  # adapted because the packaged cliphist version here predates its
  # `-fields` flag: image entries are instead detected by matching
  # cliphist's "[[ binary data <size> <format> <W>x<H> ]]" preview text.
  cliphistRofiImg = pkgs.writeShellApplication {
    name = "cliphist-rofi-img";
    runtimeInputs = [ pkgs.cliphist pkgs.gawk pkgs.wl-clipboard ];
    text = ''
      tmp_dir="''${XDG_RUNTIME_DIR:-/tmp}/cliphist-rofi-img"

      if [[ -n "''${1:-}" ]]; then
        cliphist decode <<<"$1" | wl-copy
        # Marker for cliphist-clipboard-picker: rofi runs this script
        # synchronously while its own window still has focus, so the
        # auto-paste keystroke can't be sent from here — it has to happen
        # after rofi (the caller) has actually exited and focus has
        # returned to the previously active window.
        touch "$tmp_dir/.selected"
        exit
      fi

      rm -rf "$tmp_dir"
      mkdir -p "$tmp_dir"

      # -preview-width widened so long text entries aren't cut off before
      # they even reach the (also widened) rofi window.
      cliphist list -preview-width 300 | gawk -F'\t' -v tmp_dir="$tmp_dir" '
        match($2, /^\[\[ binary data [^ ]+ [^ ]+ ([a-zA-Z0-9]+) [0-9]+x[0-9]+ \]\]$/, fmt) {
          file = tmp_dir "/" $1 "." fmt[1]
          system("cliphist decode " $1 " >" file)
          print $1 "\t" $2 "\0icon\x1f" file
          next
        }
        { print }
      '
    '';
  };

  # Theme overrides for the clipboard picker, merged (via -theme-str) into
  # the shared rofi theme/Stylix colors rather than replacing them.
  clipboardTheme = builtins.concatStringsSep " " [
    "window{width:1100px;}"
    "listview{lines:12;fixed-height:false;}"
    "element{orientation:horizontal;children:[element-text,element-icon];spacing:10px;border-radius:8px;}"
    # Stylix sets background-color on these specific per-state selectors
    # (for zebra-striping), which are more specific than a plain `element{}`
    # override, so transparency has to be set on each of them directly.
    "element normal.normal{background-color:transparent;}"
    "element alternate.normal{background-color:transparent;}"
    "element selected.normal{border-radius:8px;}"
    "element-icon{size:40px;}"
    "element-text{vertical-align:0.5;}"
  ];

  # Classes of terminal emulators whose default keybinds don't treat Ctrl+V
  # as paste (Alacritty included — it's this setup's $TERMINAL and only
  # binds Ctrl+Shift+V by default).
  terminalClasses = [ "Alacritty" "kitty" "foot" "org.wezfurlong.wezterm" "Konsole" "gnome-terminal-server" "xterm" ];

  # Runs the clipboard picker, then auto-pastes the selected entry into
  # whatever window regains focus once rofi closes (rather than leaving the
  # user to press paste manually). rofi runs cliphist-rofi-img synchronously
  # while still focused, so it can only leave a marker (see there) — the
  # actual paste keystroke has to be injected here, after rofi has exited.
  cliphistClipboardPicker = pkgs.writeShellApplication {
    name = "cliphist-clipboard-picker";
    runtimeInputs = [ pkgs.hyprland pkgs.jq pkgs.wtype ];
    text = ''
      tmp_dir="''${XDG_RUNTIME_DIR:-/tmp}/cliphist-rofi-img"
      marker="$tmp_dir/.selected"
      rm -f "$marker"

      ${rofi} -show clipboard -modi clipboard:${cliphistRofiImg}/bin/cliphist-rofi-img -show-icons -theme-str '${clipboardTheme}'

      [[ -f "$marker" ]] || exit 0
      rm -f "$marker"

      # Let focus fully return to the previously active window before
      # injecting the paste keystroke.
      sleep 0.1

      # Fire the paste combo as one atomic keypress and let the focused
      # app do its own (correct) paste/framing from the real clipboard,
      # rather than us reconstructing the bytes ourselves.
      window=$(hyprctl activewindow -j)
      class=$(jq -r '.class // empty' <<<"$window")

      # Neovide only forwards keys to Neovim, it has no paste keybind of
      # its own — Ctrl(+Shift)+V does whatever Neovim's keymap says.
      if [[ "$class" == "neovide" ]]; then
        title=$(jq -r '.title // empty' <<<"$window")
        if [[ "$title" == term://* ]]; then
          # An embedded :terminal split, focused in terminal-mode: <Esc> is
          # forwarded straight to the shell there instead of leaving
          # terminal-mode (that needs Ctrl-\ Ctrl-n), so "+p would leak in
          # as literal keystrokes. Ctrl-R + is terminal-mode's own
          # insert-register binding — it feeds the register straight into
          # the shell's input, which is the correct idiom here.
          wtype -M ctrl -k r -m ctrl -- '+'
        else
          # A normal editing buffer: default Ctrl(+Shift)+V does nothing
          # useful (e.g. enters Visual Block mode). <Esc> drops safely to
          # Normal mode (a no-op if already there), then "+p pastes the
          # system-clipboard register, matching this nvim config's
          # `set clipboard^=unnamed,unnamedplus`.
          wtype -k Escape -- '"+p'
        fi
        exit 0
      fi

      paste_keys=(-M ctrl -k v -m ctrl)
      for terminal_class in ${lib.concatMapStringsSep " " (c: "'${c}'") terminalClasses}; do
        if [[ "$class" == "$terminal_class" ]]; then
          paste_keys=(-M ctrl -M shift -k v -m shift -m ctrl)
          break
        fi
      done
      wtype "''${paste_keys[@]}"
    '';
  };
in
{
  options.${namespace}.desktop.hyprland.clipboard = with types; {
    enable = mkBoolOpt false "Enable clipboard history management (cliphist + rofi picker, with image previews).";
  };

  config = mkIf cfg.enable {
    services.cliphist = {
      enable = true;
      allowImages = true;
      # Keep 1000 entries as required (default is 750).
      extraOptions = [ "--max-items" "1000" ];
    };

    wayland.windowManager.hyprland.settings.bind = [
      {
        _args = [
          "SUPER + V"
          # NOTE: rofi's listview sizes every row uniformly (by design, not a
          # bug we can theme around: https://blog.sarine.nl/2017/04/07/rofi-140-sneak-preview4.html)
          # so a per-row "bigger only for images" height isn't possible.
          # element-icon size is kept modest so text-only rows stay compact.
          (lua ''hl.dsp.exec_cmd("${cliphistClipboardPicker}/bin/cliphist-clipboard-picker")'')
        ];
      }
    ];
  };
}
