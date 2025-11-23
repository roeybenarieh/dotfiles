{ namespace, lib, config, ... }:

with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.graphics.displays;
  # ThinkVision = DVI-I-3-2
  # Sumsung-s23c650 = DVI-I-2-1
  # builtInDisplay = eDP-1

  fingerprint = {
    DVI-I-3-2 = "00ffffffffffff0030aea16343475a322b220104b53c22783e3825af4f46a5250f5054b54f008180818a9500b300d1c0d100714f8100565e00a0a0a029503020350055502100001a000000ff0056333044325a47430a20202020000000fd00324b1e721e010a202020202020000000fc00503237682d33300a20202020200181020327f1490103020413901f1211230907078301000065030c001000e305c000e606050161561ccc7400a0a0a01e503020350055502100001a662156aa51001e30468f330055502100001e483f403062b0324040c0130055502100001e0000000000000000000000000000000000000000000000000000000000000000000085";
    DVI-I-2-1 = "00ffffffffffff004c2ddd093958595a2517010380331d782a01f1a257529f270a5054bfef80714f81c0810081809500a9c0b3000101023a801871382d40582c4500fe1f1100001e000000fd00384b1e5111000a202020202020000000fc00533233433635300a2020202020000000ff00485451443930303130350a202001ed02031b71230907078301000067030c002000802d43100403e2000f8c0ad08a20e02d10103e9600a05a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000018";
    eDP-1 = mkIf (cfg.builtInDisplay.fingerprint != null) cfg.builtInDisplay.fingerprint;
  };
in
{
  options.${namespace}.graphics.displays = with types; {
    enable = mkBoolOpt false "Whether or not to enable display related features";
    builtInDisplay = {
      fingerprint = mkstrOpt null "autorandr display fingerprint of a screen that comes built in with the machine(i.e. laptop screen)";
      config = mkOpt lib.types.attrs null "autorandr display configuration for the provided built in screen";
    };
  };
  # create new profile from current xrandr configuration(after editing it in arandr): autorandr --config
  # get new monitor fingerprint: autorandr --fingerprint
  config = mkIf cfg.enable {
    services.autorandr = {
      enable = true;
      matchEdid = true;
      profiles = {
        "Home Thinkpad dock" = {
          inherit fingerprint;
          config = {
            eDP-1 = mkIf (cfg.builtInDisplay.config != null) (cfg.builtInDisplay.config // {
              enable = true;
              position = "0x962";
              primary = true;
            });
            DVI-I-2-1 = {
              enable = true;
              mode = "1920x1080";
              position = "1920x263";
              rotate = "normal";
            };
            DVI-I-3-2 = {
              enable = true;
              mode = "2560x1440";
              position = "3840x0";
              rotate = "normal";
            };
          };
        };
      };
    };
  };
}
