{ pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    oh-my-zsh = {
      enable = true;
      plugins = [
        # "zsh-autosuggestions"
        "web-search"
        "eza"
        # "fast-syntax-highlighting"
        # "zsh-autocomplete"
        "common-aliases"
        "command-not-found"
        "colored-man-pages"
        "thefuck"
        "git"
        "fzf"
        "helm"
        # "tmux"
        "oc"
        "kubectl"
        "docker"
        "docker-compose"
        "python"
        "pip"
        "nvm"
        # "nix-zsh-completions"
      ];
      theme = "robbyrussell";
    };
    antidote = {
      enable = true;
      plugins = [ "nix-community/nix-zsh-completions" ];
    };
    zplug = {
      enable = true;

      # plugins = [
      #   { name = "zsh-users/zsh-autosuggestions"; } # Simple plugin installation
      #   # { name = "romkatv/powerlevel10k"; tags = [ as:theme depth:1 ]; } # Installations with additional options. For the list of options, please refer to Zplug README.
      # ];
    };
  };
}
