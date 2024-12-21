{ ... }:
{
  # x11 compositor with animations & rounded-corners
  services.picom = {
    enable = true;
    backend = "glx";
    extraArgs = [
      # "--experimental-backends" # for glx backend and reounded corners
      "-b" # run the backend
    ];
  };
  xdg.configFile = {
    "picom" = {
      source = ../../../picom;
      recursive = true;
    };
  };
}
