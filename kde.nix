{ pkgs, lib, ... }:

let
  # Terminal apps that need special handling (Ctrl+C = SIGINT, etc.)
  terminalApps = [
    "ghostty"
  ];

  # Apps excluded from Emacs/macOS keybindings
  excludedApps = terminalApps ++ [ "Emacs" "emacs" ];
in
{
  # ──────────────────────────────────────────────────────────────
  # plasma-manager: declarative KDE Plasma configuration
  # ──────────────────────────────────────────────────────────────
  programs.plasma.enable = true;

  # Panel at the top with centered app icons
  programs.plasma.panels = [
    {
      location = "top";
      height = 44;
      widgets = [
        "org.kde.plasma.kickoff"
        { name = "org.kde.plasma.panelspacer"; }
        {
          name = "org.kde.plasma.icontasks";
          config.General.fill = "true";
        }
        { name = "org.kde.plasma.panelspacer"; }
        {
          systemTray.items.shown = [
            "org.kde.plasma.bluetooth"
          ];
        }
        "org.kde.plasma.digitalclock"
      ];
    }
  ];

  # Global launcher shortcuts (written to [services][*.desktop] in kglobalshortcutsrc)
  programs.plasma.shortcuts = {
    # Disable KRunner shortcut (replaced by fuzzel)
    "services/org.kde.krunner.desktop"."_launch" = "none";

    # Launch fuzzel with Meta+Space
    "services/fuzzel.desktop"."_launch" = "Meta+Space";

    # macOS-like screenshot shortcuts (Spectacle)
    "org.kde.spectacle.desktop"."RectangularRegionScreenShot" = "Meta+Shift+4";
    "org.kde.spectacle.desktop"."FullScreenScreenShot" = "Meta+Shift+3";
  };

  # Desktop file for fuzzel (needed for KDE global shortcut)
  xdg.dataFile."applications/fuzzel.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Fuzzel
    Exec=fuzzel
    X-KDE-Shortcuts=Meta+Space
    NoDisplay=true
  '';

  # fcitx5: clear Super+Space from enumerate-groups hotkey (conflicts with fuzzel launcher)
  xdg.configFile."fcitx5/config".text = ''
    [Hotkey]
    EnumerateWithTriggerKeys=True
    EnumerateForwardKeys=
    EnumerateBackwardKeys=
    EnumerateSkipFirst=False
    ModifierOnlyKeyTimeout=250

    [Hotkey/TriggerKeys]
    0=Control+space
    1=Zenkaku_Hankaku
    2=Hangul

    [Hotkey/ActivateKeys]
    0=Hangul_Hanja

    [Hotkey/DeactivateKeys]
    0=Hangul_Romaja

    [Hotkey/AltTriggerKeys]
    0=Shift_L

    [Hotkey/EnumerateGroupForwardKeys]

    [Hotkey/EnumerateGroupBackwardKeys]

    [Hotkey/PrevPage]
    0=Up

    [Hotkey/NextPage]
    0=Down

    [Hotkey/PrevCandidate]
    0=Shift+Tab

    [Hotkey/NextCandidate]
    0=Tab

    [Hotkey/TogglePreedit]
    0=Control+Alt+P

    [Behavior]
    ActiveByDefault=False
    resetStateWhenFocusIn=No
    ShareInputState=No
    PreeditEnabledByDefault=True
    ShowInputMethodInformation=True
    showInputMethodInformationWhenFocusIn=False
    CompactInputMethodInformation=True
    ShowFirstInputMethodInformation=True
    DefaultPageSize=5
    OverrideXkbOption=False
    CustomXkbOption=
    EnabledAddons=
    DisabledAddons=
    PreloadInputMethod=True
    AllowInputMethodForPassword=False
    ShowPreeditForPassword=False
    AutoSavePeriod=30
  '';

  # Fuzzel: fast Wayland-native app launcher
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "monospace:size=13";
        width = 35;
        lines = 10;
        terminal = "ghostty -e";
        layer = "overlay";
        icons-enabled = "yes";
      };
      colors = {
        # Breeze Dark palette
        background = "31363bee";
        text = "fcfcfcff";
        match = "3daee9ff";
        selection = "2980b9ff";
        selection-text = "ffffffff";
        selection-match = "7fdbffff";
        border = "475057ff";
      };
      border = {
        width = 2;
        radius = 8;
      };
    };
  };

  # Mouse pointer speed (KDE System Settings > Input Devices > Mouse)
  programs.plasma.configFile."kcminputrc"."Mouse"."XLbInptPointerAcceleration" = {
    value = 0.4;
    immutable = true;
  };

  # Keyboard repeat rate for KDE Wayland
  # (services.xserver.autoRepeatDelay/Interval only apply to X11)
  # immutable = true adds [$i] marker so KDE won't overwrite these on logout
  programs.plasma.configFile."kcminputrc"."Keyboard" = {
    RepeatDelay = {
      value = 200;
      immutable = true;
    };
    RepeatRate = {
      value = 100; # chars per second (equivalent to 10ms interval)
      immutable = true;
    };
  };

  # fcitx5 as KDE Wayland virtual keyboard (required for IME on Wayland)
  programs.plasma.configFile."kwinrc"."Wayland"."InputMethod" = {
    value = "/run/current-system/sw/share/applications/fcitx5-wayland-launcher.desktop";
    immutable = true;
  };

  # Disable automatic suspend/sleep and screen lock
  programs.plasma.powerdevil.AC.autoSuspend.action = "nothing";
  programs.plasma.kscreenlocker.autoLock = false;

  # Disable Baloo, KDE's file-content indexer.
  #
  # ~/Repo holds ~400 GB of source checkouts and git worktrees; Baloo had
  # indexed 1,668,654 files into a 10 GB database, and every rebuild in a
  # worktree feeds it a fresh wave of target/ and node_modules/ churn to
  # re-scan. The desktop search it powers is not something this machine is
  # used for — grep and fd cover it.
  #
  # This only stops future indexing. Reclaim the existing database once with:
  #   balooctl6 disable && balooctl6 purge
  programs.plasma.configFile."baloofilerc"."Basic Settings"."Indexing-Enabled" = false;

  # Dark theme
  programs.plasma.workspace = {
    lookAndFeel = "org.kde.breezedark.desktop";
    colorScheme = "BreezeDark";
  };

  # Display output configuration (DP-1: Dell 4K @ 60Hz, 110% scale)
  # plasma-manager only handles INI-style .rc files, so JSON configs use xdg.configFile
  xdg.configFile."kwinoutputconfig.json".text = builtins.toJSON [
    {
      name = "outputs";
      data = [
        {
          connectorName = "DP-1";
          edidHash = "54c6df04f1576c690d54c4159c18c33d";
          edidIdentifier = "DEL 17020 842281036 8 2023 0";
          mode = {
            width = 3840;
            height = 2160;
            refreshRate = 59997;
          };
          scale = 1.1;
        }
      ];
    }
    {
      name = "setups";
      data = [
        {
          lidClosed = false;
          outputs = [
            {
              enabled = true;
              outputIndex = 0;
              position = { x = 0; y = 0; };
              priority = 1;
            }
          ];
        }
      ];
    }
  ];

  # Ghostty quick terminal (native KDE Wayland support via wlr-layer-shell-v1)
  programs.ghostty.settings = {
    keybind = [
      "global:ctrl+period=toggle_quick_terminal"
    ];
    quick-terminal-position = "top";
    quick-terminal-screen = "main";
    quick-terminal-size = "95%,70%";
    quick-terminal-animation-duration = 0;
    # I want to enable this option, but this seems buggy... when I hide the quick
    # terminal window by pressing ctrl+period, no other window can get focus even
    # if I click on them
    # quick-terminal-autohide = true;
  };

  # Autostart Ghostty so the quick terminal global keybind works
  xdg.configFile."autostart/com.mitchellh.ghostty.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Ghostty
    Exec=ghostty
    X-KDE-autostart-phase=2
  '';

  # Konsole: declarative profile using Google Sans Code
  programs.konsole = {
    defaultProfile = "GoogleSansCode";
    profiles."GoogleSansCode" = {
      font = {
        name = "Google Sans Code";
        size = 11;
      };
      colorScheme = "BreezeDark";
    };
  };

  # KDE applications
  home.packages = with pkgs; [
    kdePackages.kdenlive
    losslesscut-bin
    vlc
  ];

  # Default browser for CLI tools (xdg-open, gh, etc.)
  programs.zsh.sessionVariables.BROWSER = "firefox";

  # Overrides pinentryPackage specified in home.nix
  # Use curses so the prompt appears inline in the terminal (avoids popup hiding behind quick terminal)
  services.gpg-agent.pinentry.package = pkgs.pinentry-curses;

  # ──────────────────────────────────────────────────────────────
  # xremap: macOS-like keybindings
  # Super (Cmd) = app shortcuts, Ctrl = Emacs movement, Alt = word nav
  # ──────────────────────────────────────────────────────────────
  services.xremap = {
    enable = true;
    withKDE = true;
    watch = true;  # Re-scan /dev/input on udev add/remove so hot-plugged keyboards work

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
