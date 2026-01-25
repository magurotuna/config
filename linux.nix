{ pkgs, lib, ... }:

lib.mkIf pkgs.stdenv.isLinux {
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
      "x-scheme-handler/about" = "firefox.desktop";
      "text/html" = "firefox.desktop";
    };
  };

  home.packages = with pkgs; [
    wl-clipboard
  ];
}
