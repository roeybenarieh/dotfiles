{ pkgs, ... }:

{
  home.packages = with pkgs; [ discord zoom-us telegram-desktop ];
}
