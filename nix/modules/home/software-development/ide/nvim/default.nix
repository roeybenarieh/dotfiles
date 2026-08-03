{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.software-development.ide.neovim;
  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
  nvim-wrapper = pkgs.writeShellScriptBin "nvim-wrapper" ''
    #!/bin/sh
    if [[ -n "$WAYLAND_DISPLAY" ]]; then
      active=$(${hyprctl} activewindow -j)
      addr=$(echo "$active" | ${getExe pkgs.jq} -r '.address')
      workspace=$(echo "$active" | ${getExe pkgs.jq} -r '.workspace.id')
      ${hyprctl} dispatch "hl.dsp.window.move({ workspace = 'special:nvim-hidden', follow = false, window = 'address:$addr' })"
      ${getExe pkgs.neovide} "$@" 2>/dev/null
      ${hyprctl} dispatch "hl.dsp.window.move({ workspace = $workspace, window = 'address:$addr' })"
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
        lsof # opencode plugin
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
