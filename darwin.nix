{ pkgs, lib, ... }:

{
  # ──────────────────────────────────────────────────────────────
  # nix-darwin system configuration (macbook)
  #
  # This layer is opt-in and additive: it only manages what is declared
  # here. Anything NOT listed — display resolution, most System Settings,
  # and any brew package you haven't moved below — is left exactly as-is.
  # ──────────────────────────────────────────────────────────────

  # Like home.stateVersion: set once, then leave it. Don't bump casually.
  system.stateVersion = 5;

  # Required by newer nix-darwin for user-scoped options (homebrew, defaults).
  system.primaryUser = "yusuke";

  users.users.yusuke = {
    name = "yusuke";
    home = "/Users/yusuke";
  };

  # Enable flakes and the modern nix CLI.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # If you installed Nix with the Determinate Systems installer, uncomment the
  # next line so nix-darwin does not also try to manage the nix daemon:
  nix.enable = false;

  # zsh is the login shell on macOS; nix-darwin manages /etc/zshrc bits.
  programs.zsh.enable = true;

  # Register the Nix-built zsh as an allowed login shell (adds it to /etc/shells)
  # so we can switch to it for parity with the NixOS machines, instead of running
  # Apple's /bin/zsh. We deliberately do NOT manage the account via
  # users.knownUsers (risky for a primary macOS user); the shell is set with
  # `dscl` after switching:
  #   sudo dscl . -create /Users/yusuke UserShell /run/current-system/sw/bin/zsh
  environment.shells = [ pkgs.zsh ];

  # ──────────────────────────────────────────────────────────────
  # Homebrew — declarative, but migrated gradually.
  #
  # cleanup = "none" means nothing you installed manually is ever removed.
  # To migrate an app: add it below, run `darwin-rebuild switch`, confirm it
  # works, then `brew uninstall [--cask] <name>` to drop the manual copy.
  # (Brew must already be installed; nix-darwin does not install brew itself.)
  # ──────────────────────────────────────────────────────────────
  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "none"; # do not touch undeclared formulae/casks
      autoUpdate = false;
      upgrade = false;
    };

    taps = [ ];

    # CLI formulae generally move to home.packages (Nix), not here.
    brews = [ ];

    # GUI apps / system integrations with no good Nix darwin build stay in
    # Homebrew. Add the ones you want managed declaratively, e.g.:
    casks = [
      # "1password"
      # "1password-cli"
      "cmux"
      # Reads ~/.config/karabiner/karabiner.json managed by home.nix.
      "karabiner-elements"
      # "google-japanese-ime"
      # "raycast"
      # "rectangle"
      # "wireshark"
      # "ngrok"
      # "google-chrome"
      # "firefox"
      # "microsoft-edge"
      # "obsidian"
    ];

    # Mac App Store apps (needs the `mas` CLI):
    # masApps = { };
  };

  # ──────────────────────────────────────────────────────────────
  # macOS system defaults (opt-in). Uncomment what you want managed;
  # anything left commented stays under System Settings' control.
  # ──────────────────────────────────────────────────────────────
  # system.defaults.NSGlobalDomain.AppleInterfaceStyle = "Dark"; # dark mode
  # system.defaults.NSGlobalDomain.AppleShowAllExtensions = true;
  # system.defaults.dock.autohide = true;
  # system.defaults.finder.FXPreferredViewStyle = "Nlsv";       # list view
}
