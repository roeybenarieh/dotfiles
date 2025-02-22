{ pkgs, ... }:

{
  programs.bat = {
    enable = true;
    extraPackages = with pkgs.bat-extras; [
      prettybat # pretty print files(format the files before printing)
      batman # use bat to display man pages
      batpipe # integrate bat with other tools
    ];
  };
  home.shellAliases = {
    cat = "${pkgs.bat}/bin/bat";
  };
}
