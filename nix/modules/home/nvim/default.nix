{ namespace, lib, config, pkgs, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.neovim;
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
      # TODO: understand why this is working although it is not documented
      extraPackages = with pkgs; [
        ripgrep
        nixpkgs-fmt
        xclip
        fd

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
          size = 14.0;
        };
      };
    };
    home.shellAliases = { n = "nvim"; };
  };
}
