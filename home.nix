{ pkgs, homeDirectory, ... }:

{
  # Home Manager needs these to know where to install things
  home.username = "yusuke";
  home.homeDirectory = homeDirectory;

  # Version of Home Manager state - don't change this casually
  home.stateVersion = "24.11";

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # ──────────────────────────────────────────────────────────────
  # Packages to install
  # ──────────────────────────────────────────────────────────────
  home.packages = with pkgs; [
    # Core CLI tools
    ripgrep
    fd
    eza
    bat
    fzf
    jq
    tree
    dust
    tokei

    # Git tools
    gh
    ghq
    git-lfs
    delta  # git-delta

    # Shell enhancements
    direnv
    starship
    atuin
  ];

  # ──────────────────────────────────────────────────────────────
  # Git
  # ──────────────────────────────────────────────────────────────
  programs.git = {
    enable = true;

    signing = {
      key = "5D866BB12F68CA51";
      signByDefault = true;
    };

    settings = {
      user = {
        name = "Yusuke Tanaka";
        email = "wing0920@gmail.com";
      };
      ghq.root = "~/Repo";
      core.excludesfile = "~/.gitignore_global";
      filter.lfs = {
        process = "git-lfs filter-process";
        required = true;
        clean = "git-lfs clean -- %f";
        smudge = "git-lfs smudge -- %f";
      };
      credential = {
        "https://github.com" = {
          helper = [
            ""
            "!gh auth git-credential"
          ];
        };
        "https://gist.github.com" = {
          helper = [
            ""
            "!gh auth git-credential"
          ];
        };
        "https://github.gatech.edu" = {
          helper = [
            ""
            "!gh auth git-credential"
          ];
        };
      };
    };
  };
}
