{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.neovim;
  nvim-wrapper = pkgs.writeShellScriptBin "nvim-wrapper" ''
    #!/bin/sh
    # Get the currently active window (your Alacritty)
    win_id=$(${getExe pkgs.xdotool} getactivewindow)
    # Send it to the background
    ${getExe pkgs.xdotool} windowunmap "$win_id"
    # Launch Neovide in the same directory
    ${getExe pkgs.neovide} "$@"
    # Send original windowd to foreground (bring it back)
    ${getExe pkgs.xdotool} windowmap "$win_id"
  '';
  nvim-wrapper-executable = getExe nvim-wrapper;
in
{
  options.${namespace}.neovim = with types; {
    enable = mkBoolOpt false "Whether or not to enable neovim.";
  };

  config = mkIf cfg.enable {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      withPython3 = true;
      withNodeJs = true;
      extraLuaConfig = mkForce ""; # in order to put my own init.lua configuraiton
      # TODO: understand why this is working although it is not documented
      extraPackages = with pkgs; [
        ripgrep
        nixpkgs-fmt
        xclip
        fd
        silicon

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
    home.shellAliases = {
      n = nvim-wrapper-executable;
      nvim = nvim-wrapper-executable;
    };
  };
}
