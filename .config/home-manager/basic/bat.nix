{ pkgs, ... }:

{
  programs.bat = { enable = true; };
  home.sessionVariables = {
    MANPAGER = "sh -c 'sed -e s/.\\\\x08//g | bat --language man --plain'"; # use bat for man pages
  };
}
