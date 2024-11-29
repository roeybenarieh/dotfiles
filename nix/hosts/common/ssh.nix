{ pkgs, ... }:

{
  # Enable the OpenSSH daemon(sshd).
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      KbdInteractiveAuthentication =
        true; # ask for each autherazation interactivly
      UsePAM = true;

      # security related
      PermitRootLogin = "no";
      LoginGraceTime = "10m";
      MaxAuthTries = 10;
      MaxSessions = 3;
    };
  };
  # install google-authenticator
  environment.systemPackages = with pkgs; [ google-authenticator ];
  # use google-authenticator pam for ssh connections
  security.pam = { services.sshd.googleAuthenticator.enable = true; };
  # NOTE: this code enable google-authenticator only for ssh connections ONLY
  # NOTE: in order for the pam to work a ~/.google_authenticator file must exist for that user
  # run 'google-authenticator', follow the setup steps, and the file will automaticaly get created.
  # tutorial example: https://goteleport.com/blog/ssh-2fa-tutorial
  # NOTE: if a user doesnt have ~/.google-authenticator file, the apm still works on him, meaning he wouldn't be able to connect.
}
