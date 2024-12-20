# eza is a 'ls' alternative
{ ... }:

{
  programs.eza = {
    enable = true;
    extraOptions = [
      "--git" # List each file's Git status if tracked or ignored
      "--icons" # Display icons next to file names
      "--group" # Display the group of the resourcd
    ];
  };
  home.shellAliases = {
    l = "ls -lh"; # defaulty l = "ls -lFh", and -F doesnt exists in eza.
  };
}
