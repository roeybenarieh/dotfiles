{ ... }:

{
  imports = [ ./tor.nix ./chromium.nix ./firefox ];
  # make firefox the default for opening things
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "firefox.desktop";
      "application/pdf" = "firefox.desktop";
      "image/jpeg" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
      "x-scheme-handler/about" = "firefox.desktop";
      "x-scheme-handler/unknown" = "firefox.desktop";
    };
  };
}
