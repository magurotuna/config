{ pkgs, lib, ... }:

let
  # Terminal apps that need special handling (Ctrl+C = SIGINT, etc.)
  terminalApps = [
    "gnome-terminal"
    "org.gnome.Console"  # GNOME Console
    "kitty"
    "alacritty"
    "wezterm"
    "foot"
    "tilix"
    "terminator"
    "konsole"
    "xterm"
  ];

  # Apps excluded from Emacs/macOS keybindings
  excludedApps = terminalApps ++ [ "Emacs" "emacs" ];
in
{
  # xremap GNOME Shell extension for app detection on Wayland
  home.packages = [ pkgs.gnomeExtensions.xremap ];

  dconf.settings = {
    "org/gnome/shell" = {
      disable-user-extensions = false;
      enabled-extensions = [ pkgs.gnomeExtensions.xremap.extensionUuid ];
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

  # ──────────────────────────────────────────────────────────────
  # xremap: macOS-like keybindings
  # Super (Cmd) = app shortcuts, Ctrl = Emacs movement, Alt = word nav
  # ──────────────────────────────────────────────────────────────
  services.xremap = {
    enable = true;
    withGnome = true;

    config = {
      modmap = [
        {
          name = "CapsLock to Ctrl";
          remap = { CapsLock = "Ctrl_L"; };
        }
      ];

      keymap = [
        # ── Emacs-style cursor movement (like macOS system-wide) ──
        {
          name = "Emacs cursor movement";
          application.not = excludedApps;
          remap = {
            # Movement
            C-f = "Right";          # Forward char
            C-b = "Left";           # Backward char
            C-n = "Down";           # Next line
            C-p = "Up";             # Previous line
            C-a = "Home";           # Beginning of line
            C-e = "End";            # End of line
            # Deletion
            C-d = "Delete";         # Delete forward
            C-h = "Backspace";      # Delete backward
            C-k = [ "Shift-End" "Delete" ];  # Kill to end of line
            # Selection
            C-Shift-f = "Shift-Right";
            C-Shift-b = "Shift-Left";
            C-Shift-n = "Shift-Down";
            C-Shift-p = "Shift-Up";
          };
        }

        # ── macOS-like shortcuts (Super → Ctrl) ──
        {
          name = "macOS-like shortcuts";
          application.not = excludedApps;
          remap = {
            # Copy/Paste/Cut
            Super_L-c = "C-c";
            Super_L-v = "C-v";
            Super_L-x = "C-x";
            # Common editing
            Super_L-a = "C-a";        # Select all
            Super_L-z = "C-z";        # Undo
            Super_L-Shift-z = "C-y";  # Redo
            Super_L-y = "C-y";        # Redo alternative
            Super_L-s = "C-s";        # Save
            Super_L-Shift-s = "C-Shift-s";  # Save as
            # Find/Replace
            Super_L-f = "C-f";        # Find
            Super_L-g = "C-g";        # Find next
            Super_L-Shift-g = "C-Shift-g";  # Find previous
            Super_L-h = "C-h";        # Replace
            # Tab/Window management
            Super_L-t = "C-t";        # New tab
            Super_L-w = "C-w";        # Close tab
            Super_L-Shift-t = "C-Shift-t";  # Reopen closed tab
            Super_L-n = "C-n";        # New window
            Super_L-Shift-n = "C-Shift-n";  # New incognito/private window
            # Navigation
            Super_L-l = "C-l";        # Focus address bar
            Super_L-r = "C-r";        # Reload
            Super_L-Shift-r = "C-Shift-r";  # Hard reload
            # Text navigation (macOS-style)
            Super_L-Left = "Home";
            Super_L-Right = "End";
            Super_L-Up = "C-Home";
            Super_L-Down = "C-End";
            Super_L-Backspace = "C-Shift-Backspace";
            # Selection with navigation
            Super_L-Shift-Left = "Shift-Home";
            Super_L-Shift-Right = "Shift-End";
            Super_L-Shift-Up = "C-Shift-Home";
            Super_L-Shift-Down = "C-Shift-End";
            # Other
            Super_L-p = "C-p";        # Print
            Super_L-o = "C-o";        # Open
            Super_L-b = "C-b";        # Bold
            Super_L-i = "C-i";        # Italic
            Super_L-u = "C-u";        # Underline
            # Zoom
            Super_L-equal = "C-equal";
            Super_L-minus = "C-minus";
            Super_L-0 = "C-0";
          };
        }

        # ── Terminal-specific shortcuts ──
        {
          name = "Terminal shortcuts";
          application.only = terminalApps;
          remap = {
            Super_L-c = "C-Shift-c";
            Super_L-v = "C-Shift-v";
            Super_L-t = "C-Shift-t";
            Super_L-n = "C-Shift-n";
            Super_L-w = "C-Shift-w";
            Super_L-f = "C-Shift-f";
            Super_L-k = "C-l";        # Clear terminal
            Super_L-equal = "C-Shift-equal";
            Super_L-minus = "C-Shift-minus";
            Super_L-0 = "C-Shift-0";
          };
        }

        # ── Word navigation with Alt (works everywhere) ──
        {
          name = "Word navigation with Alt";
          remap = {
            Alt_L-Left = "C-Left";
            Alt_L-Right = "C-Right";
            Alt_L-Backspace = "C-Backspace";
            Alt_L-Delete = "C-Delete";
            Alt_L-Shift-Left = "C-Shift-Left";
            Alt_L-Shift-Right = "C-Shift-Right";
          };
        }
      ];
    };
  };
}
