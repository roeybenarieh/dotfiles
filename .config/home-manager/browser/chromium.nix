{ pkgs, ... }:

{
  programs.chromium = {
    enable = true;
    extensions = [
      { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # ublock origin
      { id = "dbepggeogbaibhgnhhndojpepiihcmeb"; } # vimium
      { id = "gmegofmjomhknnokphhckolhcffdaihd"; } # jsonview
      { id = "aapbdbdomjkkjkaonfhkkikfgjllcleb"; } # google-translate
      { id = "eimadpbcbfnmbkopoojfekhnkhdbieeh"; } # dark-reader
      { id = "klehggjefofgiajjfpoebdidnpjmljhb"; } # duplicate tab shortcat with Alt+Shift+D
    ];
    dictionaries = with pkgs; [
      hunspellDictsChromium.en_US
    ];
  };
}
