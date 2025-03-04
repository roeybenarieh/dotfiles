{ pkgs, ... }:

{
  imports = [ ./neovim.nix ];
  programs.vscode = {
    enable = true;
    profiles.default.extensions = with pkgs; [
      vscode-extensions.ms-python.python # microsoft python extension
      vscode-extensions.esbenp.prettier-vscode # prettier formatter
      vscode-extensions.charliermarsh.ruff # python ruff linter
    ];
  };
}
