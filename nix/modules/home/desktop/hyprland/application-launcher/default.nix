{ namespace, lib, config, pkgs, inputs, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.desktop.hyprland.applicationLauncher;
  lua = lib.generators.mkLuaInline;
  papirus = pkgs.papirus-icon-theme;
  icon = name: "${papirus}/share/icons/Papirus/48x48/apps/${name}.svg";

  # Icon-grid layout for the drun app launcher only. `programs.rofi.theme`
  # below is shared by every rofi invocation (e.g. the clipboard picker's
  # `rofi -dmenu`), so the grid must NOT live there or plain text lists get
  # squeezed into icon-sized tiles. Applied via `-theme-str`, which merges
  # into the shared theme instead of replacing it.
  drunGridTheme = builtins.concatStringsSep " " [
    "listview{columns:5;lines:3;cycle:true;dynamic:true;scrollbar:false;layout:vertical;reverse:false;fixed-height:true;fixed-columns:true;spacing:0px;margin:0px;padding:0px;border:0px solid;border-radius:0px;cursor:default;}"
    "element{enabled:true;spacing:15px;margin:0px;padding:20px 10px;border:0px solid;border-radius:10px;orientation:vertical;cursor:pointer;}"
    "element-icon{size:64px;cursor:inherit;}"
    "element-text{highlight:inherit;cursor:inherit;vertical-align:0.5;horizontal-align:0.5;}"
  ];
in
{
  options.${namespace}.desktop.hyprland.applicationLauncher = with types; {
    enable = mkBoolOpt false "Enable the application launcher (rofi).";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ rofimoji papirus ];

    # Layout/behaviour only. Colors and font are intentionally left unset so
    # that Stylix's rofi target (autoEnabled) can theme them.
    programs.rofi = {
      enable = true;

      extraConfig = {
        modi = "drun";
        show-icons = true;
        display-drun = "";
        icon-theme = "Papirus";
        drun-display-format = "{name}";
        drun-use-desktop-cache = true;
        matching = "fuzzy";
        sort = true;
        sorting-method = "fzf";
        # Keep launch history so frequently/recently used apps float to the
        # top of the list when no search query is typed.
        disable-history = false;
        max-history-size = 25;
        kb-cancel = "Escape,F12";
        kb-move-char-back = "Control+b";
        kb-move-char-forward = "Control+f";
        kb-row-left = "Left";
        kb-row-right = "Right";
        kb-row-up = "Up,Control+p";
        kb-row-down = "Down,Control+n";
      };

      theme =
        let
          inherit (config.lib.formats.rasi) mkLiteral;
        in
        {
          window = {
            transparency = "real";
            location = mkLiteral "center";
            anchor = mkLiteral "center";
            fullscreen = false;
            width = mkLiteral "750px";
            x-offset = mkLiteral "0px";
            y-offset = mkLiteral "0px";
            enabled = true;
            margin = mkLiteral "0px";
            padding = mkLiteral "0px";
            border = mkLiteral "0px solid";
            border-radius = mkLiteral "12px";
            cursor = "default";
          };

          mainbox = {
            enabled = true;
            spacing = mkLiteral "20px";
            margin = mkLiteral "0px";
            padding = mkLiteral "20px";
            border = mkLiteral "0px solid";
            border-radius = mkLiteral "0px 0px 0px 0px";
            children = [ "inputbar" "listview" ];
          };

          inputbar = {
            enabled = true;
            spacing = mkLiteral "10px";
            margin = mkLiteral "0px";
            padding = mkLiteral "15px";
            border = mkLiteral "0px solid";
            border-radius = mkLiteral "10px";
            children = [ "prompt" "entry" ];
          };

          prompt.enabled = true;

          textbox-prompt-colon = {
            enabled = true;
            expand = false;
            str = "::";
          };

          entry = {
            enabled = true;
            cursor = mkLiteral "text";
            placeholder = "Search";
          };

          scrollbar = {
            handle-width = mkLiteral "5px";
            border-radius = mkLiteral "0px";
          };

          error-message = {
            padding = mkLiteral "15px";
            border = mkLiteral "2px solid";
            border-radius = mkLiteral "10px";
          };

          textbox = {
            vertical-align = mkLiteral "0.5";
            horizontal-align = mkLiteral "0.0";
            highlight = mkLiteral "none";
          };
        };
    };

    xdg.desktopEntries = {
      power-shutdown = {
        name = "Shutdown";
        exec = "systemctl -i poweroff";
        icon = icon "system-shutdown";
        categories = [ "System" ];
      };
      power-restart = {
        name = "Restart";
        exec = "systemctl -i reboot";
        icon = icon "system-reboot";
        categories = [ "System" ];
      };
      power-hibernate = {
        name = "Hibernate";
        exec = "systemctl -i hibernate";
        icon = icon "system-hibernate";
        categories = [ "System" ];
      };
      power-suspend = {
        name = "Suspend";
        exec = "systemctl -i suspend";
        icon = icon "system-suspend";
        categories = [ "System" ];
      };
      power-lock-screen = {
        name = "Lock Screen";
        exec = "hyprlock";
        icon = icon "system-lock-screen";
        categories = [ "System" ];
      };
    };

    wayland.windowManager.hyprland.settings.bind = [
      { _args = [ "SUPER + Super_L" (lua ''hl.dsp.exec_cmd("pgrep -x rofi >/dev/null && pkill -x rofi || ${config.programs.rofi.finalPackage}/bin/rofi -show drun -theme-str '${drunGridTheme}'")'') ]; }
      { _args = [ "SUPER + semicolon" (lua ''hl.dsp.exec_cmd("${pkgs.rofimoji}/bin/rofimoji")'') ]; }
    ];

    # `drun-use-desktop-cache` speeds up rofi but goes stale whenever a
    # rebuild adds/removes a .desktop entry, hiding new apps from the
    # launcher until the cache is cleared. Drop it on every activation so it
    # gets rebuilt fresh on the next launcher open.
    home.activation.clearRofiDrunCache = inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD rm -f $VERBOSE_ARG "$HOME/.cache/rofi-drun-desktop.cache" "$HOME/.cache/rofi3.druncache"
    '';
  };
}
