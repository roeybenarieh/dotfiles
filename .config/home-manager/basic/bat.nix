{ pkgs, ... }:

{
  programs.bat = { enable = true; };
  # display man pages using bat
  home.sessionVariables = {
    MANPAGER = "sh -c 'col -bx | ${pkgs.bat}/bin/bat -l man -p'";
    MANROFFOPT = "-c";
  };
  home.shellAliases = {
    cat = "${pkgs.bat}/bin/bat";
  };
}
