{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.software-development.ide.neovim;
  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
  real-nvim = getExe config.programs.neovim.finalPackage;
  nvim-wrapper = pkgs.writeShellScriptBin "nvim-wrapper" ''
    if [[ -z "$HYPRLAND_INSTANCE_SIGNATURE" && -z "$DISPLAY" ]]; then
      # No GUI available (e.g. plain TTY or SSH session) — just open regular neovim.
      exec ${real-nvim} "$@"
    elif [[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
      set -e -o pipefail
      # A special workspace still appears in workspace bars. Park the terminal
      # on a headless output instead, outside the physical monitors' workspaces.
      active=$(${hyprctl} -j activewindow)
      addr=$(printf '%s' "$active" | ${getExe pkgs.jq} -er '.address') || exec ${getExe pkgs.neovide} --no-fork "$@"
      workspace=$(printf '%s' "$active" | ${getExe pkgs.jq} -r '.workspace.id')
      output=NEOVIDE-HIDDEN
      exec 9>"$XDG_RUNTIME_DIR/nvim-wrapper-output.lock"
      ${pkgs.util-linux}/bin/flock 9

      restore_terminal() {
        ${pkgs.util-linux}/bin/flock 9
        ${hyprctl} dispatch "hl.dsp.window.move({ workspace = $workspace, window = 'address:$addr' })" >/dev/null
        # Other Neovide sessions may still be using this output.
        if ! ${hyprctl} -j workspaces | ${getExe pkgs.jq} -e --arg output "$output" 'any(.[]; .monitor == $output and .windows > 0)' >/dev/null; then
          ${hyprctl} output remove "$output" >/dev/null
        fi
        ${pkgs.util-linux}/bin/flock -u 9
      }
      trap restore_terminal EXIT
      trap 'exit 130' INT
      trap 'exit 143' TERM
      trap 'exit 129' HUP
      if ! ${hyprctl} -j monitors | ${getExe pkgs.jq} -e --arg output "$output" 'any(.[]; .name == $output)' >/dev/null; then
        # Keep the virtual screen far away so the pointer cannot drift into it.
        ${hyprctl} eval "hl.monitor({ output = '$output', mode = '640x480@60', position = '-100000x-100000', scale = 1 })" >/dev/null
        ${hyprctl} output create headless "$output" >/dev/null
      fi
      hidden_workspace=$(${hyprctl} -j monitors | ${getExe pkgs.jq} -er --arg output "$output" '.[] | select(.name == $output) | .activeWorkspace.id')
      ${hyprctl} dispatch "hl.dsp.window.move({ workspace = $hidden_workspace, follow = false, window = 'address:$addr' })" >/dev/null
      ${pkgs.util-linux}/bin/flock -u 9
      ${getExe pkgs.neovide} --no-fork "$@" 9>&- 2>/dev/null
    else
      win_id=$(${getExe pkgs.xdotool} getactivewindow)
      ${getExe pkgs.xdotool} windowunmap "$win_id"
      ${getExe pkgs.neovide} "$@" 2>/dev/null
      ${getExe pkgs.xdotool} windowmap "$win_id"
    fi
  '';
  nvim-wrapper-executable = getExe nvim-wrapper;
in
{
  options.${namespace}.software-development.ide.neovim = with types; {
    enable = mkBoolOpt false "Whether or not to enable neovim.";
  };

  config = mkIf cfg.enable {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      withPython3 = true;
      withNodeJs = true;
      initLua = mkForce ""; # in order to put my own init.lua configuraiton
      # TODO: understand why this is working although it is not documented
      extraPackages = with pkgs; [
        ripgrep
        nixpkgs-fmt
        xclip
        fd
        silicon
        lua51Packages.luarocks
        statix # nix linter

        # languages
        gcc
        go
        # rust
        cargo
        rustc
        # markdown
        marksman
      ];
    };
    programs.neovide = {
      enable = true;
      settings = {
        fork = false;
        frame = "full";
        idle = true;
        maximized = false;
        # neovim-bin = "/usr/bin/nvim";
        no-multigrid = false;
        srgb = false;
        tabs = true;
        theme = "auto";
        mouse-cursor-icon = "arrow";
        title-hidden = true;
        vsync = true;
        wsl = false;

        font = {
          normal = [ "JetBrainsMono Nerd Font" ];
          size = mkForce 11.0;
        };
      };
    };
    home.shellAliases = rec {
      nvim = nvim-wrapper-executable;
      n = nvim;
      cn = "clear;${nvim}";
    };

    xdg.mimeApps.defaultApplications = {
      "text/plain" = "neovide.desktop";
    };
  };
}
