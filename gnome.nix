{ pkgs, lib, ... }:

{
  dconf.settings = {
    "org/gnome/desktop/input-sources" = {
      xkb-options = [ "ctrl:nocaps" ];
    };

    "org/gnome/desktop/interface" = { color-scheme = "prefer-dark"; };

    "org/gnome/desktop/peripherals/keyboard" = {
      repeat = true;
      delay = lib.hm.gvariant.mkUint32 200;
      repeat-interval = lib.hm.gvariant.mkUint32 20;
    };
  };

  # Overrides pinentryPackage specified in home.nix
  services.gpg-agent.pinentry.package = pkgs.pinentry-gnome3;
}
