{ pkgs, lib, ... }:

lib.mkIf pkgs.stdenv.isLinux {
  # KDE overwrites mimeapps.list at runtime, causing conflicts on next home-manager switch.
  xdg.configFile."mimeapps.list".force = true;
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
      "x-scheme-handler/about" = "firefox.desktop";
      "text/html" = "firefox.desktop";
      "x-scheme-handler/slack" = "slack.desktop";
    };
  };

  home.packages = with pkgs; [
    wl-clipboard
    heaptrack
  ];
}
