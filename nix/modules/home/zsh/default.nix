{ namespace, lib, config, ... }:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.zsh;
in
{
  options.${namespace}.zsh = with types; {
    enable = mkBoolOpt false "Whether or not to enable zsh.";
  };

  config = mkIf cfg.enable {
    nixpkgs.config.users.defaultUserShell = pkgs.zsh;

    programs.zsh = {
      enable = true;
      # Enable completion for aliases
      initContent = "setopt complete_aliases";

      # save timestamp to records
      history.extended = true;

      oh-my-zsh = {
        enable = true;
        plugins = [
          # "zsh-autosuggestions"
          "web-search"
          "eza"
          # "fast-syntax-highlighting"
          # "zsh-autocomplete"
          "common-aliases"
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
        enable = false;

        # plugins = [
        #   { name = "zsh-users/zsh-autosuggestions"; } # Simple plugin installation
        #   # { name = "romkatv/powerlevel10k"; tags = [ as:theme depth:1 ]; } # Installations with additional options. For the list of options, please refer to Zplug README.
        # ];
      };
    };
  };
}
