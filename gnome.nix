{ pkgs, lib, ... }:

let
  # Terminal apps that need special handling (Ctrl+C = SIGINT, etc.)
  # Tips: See this page for how to obtain application identifiers:
  # https://github.com/xremap/xremap/tree/2540f76e0b5d2546afc61d4fe312a18c3bdd2b7a?tab=readme-ov-file#gnome-wayland
  terminalApps = [
    "org.gnome.Console"
    "com.mitchellh.ghostty"
  ];

  # Apps excluded from Emacs/macOS keybindings
  excludedApps = terminalApps ++ [ "Emacs" "emacs" ];
in
{
  home.packages = [
    pkgs.gnomeExtensions.xremap         # For xremap app detection on Wayland
    pkgs.gnomeExtensions.quake-terminal # Dropdown terminal toggle
    pkgs.gnomeExtensions.kimpanel       # Input method panel integration
  ];

  dconf.settings = {
    "org/gnome/shell" = {
      disable-user-extensions = false;
      enabled-extensions = [
        pkgs.gnomeExtensions.xremap.extensionUuid
        pkgs.gnomeExtensions.quake-terminal.extensionUuid
        pkgs.gnomeExtensions.kimpanel.extensionUuid
      ];
    };

    "org/gnome/desktop/interface" = { color-scheme = "prefer-dark"; };

    # Use Super+Space for Activities instead of just Super
    "org/gnome/mutter" = { overlay-key = ""; };
    "org/gnome/shell/keybindings" = { toggle-overview = [ "<Super>space" ]; };

    "org/gnome/desktop/background" = {
      picture-uri = "file://${pkgs.nixos-artwork.wallpapers.binary-black.src}";
      picture-uri-dark = "file://${pkgs.nixos-artwork.wallpapers.binary-black.src}";
      picture-options = "zoom";
    };

    "org/gnome/desktop/peripherals/keyboard" = {
      repeat = true;
      delay = lib.hm.gvariant.mkUint32 200;
      repeat-interval = lib.hm.gvariant.mkUint32 20;
    };

    # Keep XF86Keyboard for input switching (Super+Space is used by Activities)
    "org/gnome/desktop/wm/keybindings" = {
      switch-input-source = [ "XF86Keyboard" ];
      switch-input-source-backward = [ "<Shift>XF86Keyboard" ];
    };

    # Quake-terminal extension settings
    "org/gnome/shell/extensions/quake-terminal" = {
      terminal-id = "com.mitchellh.ghostty.desktop";
      terminal-shortcut = [ "<Control>period" ];
      vertical-size = 100;      # 100% of screen height
      horizontal-size = 70;     # 70% of screen width
      animation-time = 10;      # Faster animation (ms)
      skip-taskbar = true;      # Don't show in Alt+Tab
      hide-on-unfocus = false;  # Don't hide when focus is lost
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
            Super-c = "C-c";
            Super-v = "C-v";
            Super-x = "C-x";
            # Common editing
            Super-a = "C-a";        # Select all
            Super-z = "C-z";        # Undo
            Super-Shift-z = "C-y";  # Redo
            Super-y = "C-y";        # Redo alternative
            Super-s = "C-s";        # Save
            Super-Shift-s = "C-Shift-s";  # Save as
            # Find/Replace
            Super-f = "C-f";        # Find
            Super-g = "C-g";        # Find next
            Super-Shift-g = "C-Shift-g";  # Find previous
            Super-h = "C-h";        # Replace
            # Tab/Window management
            Super-t = "C-t";        # New tab
            Super-w = "C-w";        # Close tab
            Super-Shift-t = "C-Shift-t";  # Reopen closed tab
            Super-n = "C-n";        # New window
            Super-Shift-n = "C-Shift-n";  # New incognito/private window
            # Navigation
            Super-l = "C-l";        # Focus address bar
            Super-r = "C-r";        # Reload
            Super-Shift-r = "C-Shift-r";  # Hard reload
            # Text navigation (macOS-style)
            Super-Left = "Home";
            Super-Right = "End";
            Super-Up = "C-Home";
            Super-Down = "C-End";
            Super-Backspace = "C-Shift-Backspace";
            # Selection with navigation
            Super-Shift-Left = "Shift-Home";
            Super-Shift-Right = "Shift-End";
            Super-Shift-Up = "C-Shift-Home";
            Super-Shift-Down = "C-Shift-End";
            # Other
            Super-p = "C-p";        # Print
            Super-o = "C-o";        # Open
            Super-b = "C-b";        # Bold
            Super-i = "C-i";        # Italic
            Super-u = "C-u";        # Underline
            # Zoom
            Super-equal = "C-equal";
            Super-minus = "C-minus";
            Super-0 = "C-0";
          };
        }

        # ── Terminal-specific shortcuts ──
        {
          name = "Terminal shortcuts";
          application.only = terminalApps;
          remap = {
            Super-c = "C-Shift-c";
            Super-v = "C-Shift-v";
            Super-t = "C-Shift-t";
            Super-n = "C-Shift-n";
            Super-w = "C-Shift-w";
            Super-f = "C-Shift-f";
            Super-k = "C-l";        # Clear terminal
            Super-equal = "C-Shift-equal";
            Super-minus = "C-Shift-minus";
            Super-0 = "C-Shift-0";
          };
        }

        # ── Word navigation with Alt (works everywhere) ──
        {
          name = "Word navigation with Alt";
          remap = {
            Alt-Left = "C-Left";
            Alt-Right = "C-Right";
            Alt-Backspace = "C-Backspace";
            Alt-Delete = "C-Delete";
            Alt-Shift-Left = "C-Shift-Left";
            Alt-Shift-Right = "C-Shift-Right";
          };
        }
      ];
    };
  };
}
