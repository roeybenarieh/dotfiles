{ pkgs, ... }:

{
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

      # python related
      pyright
      python311Packages.debugpy
      python311Packages.ruff
    ];
  };
  home.shellAliases = { n = "nvim"; };
}
