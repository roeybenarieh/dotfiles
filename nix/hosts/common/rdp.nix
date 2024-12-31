{ pkgs, ... }:

{
  # enable xfce desktop environment for rdp connections
  services.xserver.desktopManager.xfce.enable = true;
  services.xrdp = {
    enable = true;
    audio.enable = true;
    defaultWindowManager = "xfce4-session";
    openFirewall = true;

    # this file is eventually created in /etc/xrdp/sesman.ini
    extraConfDirCommands = ''
      substituteInPlace $out/sesman.ini \
        --replace MaxSessions=50 MaxSessions=1 \
        --replace AllowRootLogin=true AllowRootLogin=false \
        --replace KillDisconnected=false KillDisconnected=true \
        --replace DisconnectedTimeLimit=0 DisconnectedTimeLimit=600

      substituteInPlace $out/xrdp.ini \
      --replace "opt=" "opt=ask" \
    '';
  };

  # install google-authenticator
  environment.systemPackages = with pkgs; [ google-authenticator ];
  # use google-authenticator pam for xrdp connections
  security.pam = {
    # wtf is the 'xrdp-sesman' service?
    # services.xrdp.googleAuthenticator = { enable = true; };
    # for more info: https://github.com/neutrinolabs/xrdp/issues/1210 there is an example configuration
    services.xrdp-sesman.googleAuthenticator = { enable = true; };
  };
  # NOTE: this code enable google-authenticator only for Xrdp connections ONLY
  # NOTE: in order for the pam to work a ~/.google_authenticator file must exist for that user
  # run 'google-authenticator', follow the setup steps, and the file will automaticaly get created.
  # tutorial example: https://goteleport.com/blog/ssh-2fa-tutorial
  # NOTE: if a user doesnt have ~/.google-authenticator file, the apm still works on him, meaning he wouldn't be able to connect.
}
