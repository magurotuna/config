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
  # XDG Config Files
  # ──────────────────────────────────────────────────────────────
  xdg.configFile."nvim/init.lua".source = ./nvim/init.lua;
  xdg.configFile."nvim/lua".source = ./nvim/lua;

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
    neovim
    neofetch
    tree-sitter

    # Git tools
    gh
    ghq
    git-lfs
    delta
    gnupg

    # Shell / terminal
    zellij

    # Network / HTTP
    oha
    websocat

    # Kubernetes
    k9s
    stern
    kubectl
    kubernetes-helm
    minikube
    talosctl

    # Cloud / Infrastructure
    awscli2
    terraform
    google-cloud-sql-proxy
    minio
    minio-client

    # Databases
    duckdb
    redis

    # Languages / Build tools
    protobuf
    typst
    ast-grep
    deno
    nodejs
    pnpm
    zig
    rustc
    cargo
    clippy
    rustfmt
    cargo-edit
    cargo-expand
    bun

    # Language servers
    lua-language-server
    nodePackages.typescript-language-server
    rust-analyzer
    gopls
    pyright
    zls

    # Other
    imagemagick

    # Load testing
    k6
    hey

    # Python
    python3
    uv

    # Learning
    codecrafters-cli

    # AI
    codex
    gemini-cli
    claude-code
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

    # Global gitignore patterns
    ignores = [
      # Personal
      "MAGURO_LOCAL_NOTE.md"

      # macOS
      ".DS_Store"
      ".AppleDouble"
      ".LSOverride"
      "._*"

      # Windows
      "Thumbs.db"
      "Desktop.ini"

      # Editors
      "*~"
      "*.swp"
      "*.swo"
      ".idea/"
      "*.iml"

      # Vim
      "Session.vim"
      ".netrwhist"

      # direnv
      ".direnv/"

      # Environment files (secrets)
      ".env.local"
      ".env.*.local"
    ];

    settings = {
      user = {
        name = "Yusuke Tanaka";
        email = "wing0920@gmail.com";
      };
      ghq.root = "~/Repo";
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

  # ──────────────────────────────────────────────────────────────
  # Zsh
  # ──────────────────────────────────────────────────────────────
  programs.zsh = {
    enable = true;

    # History settings
    history = {
      size = 100000;
      save = 1000000;
      path = "$HOME/.zsh_history";
      ignoreDups = true;
      ignoreAllDups = true;
      expireDuplicatesFirst = true;
      share = true;
    };

    # Shell options
    autocd = true;
    defaultKeymap = "emacs";

    # Environment variables
    sessionVariables = {
      # Language
      LANGUAGE = "en_US.UTF-8";
      LANG = "en_US.UTF-8";
      LC_ALL = "en_US.UTF-8";
      LC_CTYPE = "en_US.UTF-8";

      # Editor
      EDITOR = "nvim";
      CVSEDITOR = "nvim";
      SVN_EDITOR = "nvim";
      GIT_EDITOR = "nvim";

      # Pager
      PAGER = "less";
      LESS = "-R -f -X -i -P ?f%f:(stdin). ?lb%lb?L/%L.. [?eEOF:?pb%pb\\%..]";
      LESSCHARSET = "utf-8";
      # Note: LESS_TERMCAP_* variables are set in initContent with proper escaping

      # ls colors
      LSCOLORS = "exfxcxdxbxegedabagacad";
      LS_COLORS = "di=34:ln=35:so=32:pi=33:ex=31:bd=46;34:cd=43;34:su=41;30:sg=46;30:tw=42;30:ow=43;30";

      # XDG
      XDG_CONFIG_HOME = "$HOME/.config";
      XDG_DATA_HOME = "$HOME/.local/share";

      # fzf
      FZF_DEFAULT_OPTS = "--extended --ansi --multi";

      # GPG - Note: GPG_TTY is set in initContent since $(tty) needs evaluation

      # k8s
      KUBECONFIG = "$HOME/.kube/config";
    };

    # Aliases
    shellAliases = {
      # eza
      l = "eza";
      ls = "eza";
      ll = "eza -l";
      la = "eza -a";
      lla = "eza -la";

      # Common tools
      cat = "bat";
      cp = "cp -i";
      mv = "mv -i";
      rm = "rm -i";

      # Docker
      dc = "docker-compose";

      # Git
      g = "git";
      gs = "git status";
      gc = "git commit";
      gco = "git checkout";
      gsw = "git switch";
      gr = "git restore";
      ga = "git add";
      gp = "git push origin HEAD";
      gpf = "git push origin HEAD --force-with-lease";
      gdi = "git diff";
      gpu = "git pull";

      # Editors
      vi = "nvim";
      vim = "nvim";

      # Cargo
      ca = "cargo";

      # Clipboard (Linux)
      pbcopy = "xsel --clipboard --input";
      pbpaste = "xsel --clipboard --output | tr -d \"\\r\"";

      # Deno Deploy environments
      local_deployctl = "DENO_TLS_CA_STORE=system DEPLOY_API_ENDPOINT=\"https://deno-local.com\" deployctl";
      dev_deployctl = "DEPLOY_API_ENDPOINT=\"https://dash.deno-dev.com\" deployctl";
      staging_deployctl = "DEPLOY_API_ENDPOINT=\"https://deno-staging.com\" deployctl";
    };

    # Raw zsh configuration
    initContent = ''
      # Additional shell options
      setopt no_global_rcs
      setopt AUTO_PARAM_KEYS

      # Disable accept-line-and-down-history
      bindkey -r "^O"

      # LESS man page colors (must use $'...' for escape codes)
      export LESS_TERMCAP_mb=$'\E[01;31m'
      export LESS_TERMCAP_md=$'\E[01;31m'
      export LESS_TERMCAP_me=$'\E[0m'
      export LESS_TERMCAP_se=$'\E[0m'
      export LESS_TERMCAP_so=$'\E[00;44;37m'
      export LESS_TERMCAP_ue=$'\E[0m'
      export LESS_TERMCAP_us=$'\E[01;32m'

      # GPG
      export GPG_TTY=$(tty)

      # Additional PATH entries
      export PATH="/usr/local/bin:$HOME/bin:$PATH"
      export PATH="$HOME/go/bin:$PATH"
      export PATH="/snap/bin:$PATH"

      # uv (Python) - managed by Nix
      if command -v uv &> /dev/null; then
        eval "$(uv generate-shell-completion zsh)"
      fi


      # ─────────────────────────────────────────────────────────────
      # Zinit (plugin manager)
      # ─────────────────────────────────────────────────────────────
      ZINIT_HOME="''${XDG_DATA_HOME:-''${HOME}/.local/share}/zinit/zinit.git"
      if [[ ! -d $ZINIT_HOME ]]; then
        mkdir -p "$(dirname $ZINIT_HOME)"
        git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
      fi
      source "''${ZINIT_HOME}/zinit.zsh"
      autoload -Uz _zinit
      (( ''${+_comps} )) && _comps[zinit]=_zinit

      # Zinit annexes
      zinit light-mode for \
        zdharma-continuum/z-a-rust \
        zdharma-continuum/z-a-as-monitor \
        zdharma-continuum/z-a-patch-dl \
        zdharma-continuum/z-a-bin-gem-node

      # Completions
      zinit ice blockf atpull'zinit creinstall -q .'
      zinit light zsh-users/zsh-completions
      autoload compinit
      compinit

      # Syntax highlighting and autosuggestions
      zinit light zdharma/fast-syntax-highlighting
      zinit light zsh-users/zsh-autosuggestions

      # fzf integration
      [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

      # ─────────────────────────────────────────────────────────────
      # Custom functions
      # ─────────────────────────────────────────────────────────────
      # Repository fuzzy finder (ghq + fzf)
      function select_ghq() {
        local target_dir=$(ghq list -p | fzf --scheme=path --layout=reverse --no-multi --query="$LBUFFER" --prompt="Repo > ")
        if [ -n "$target_dir" ]; then
          BUFFER="cd ''${target_dir}"
          zle accept-line
        fi
        zle reset-prompt
      }
      zle -N select_ghq
      bindkey "^g" select_ghq

      # ─────────────────────────────────────────────────────────────
      # Secrets (not tracked in git)
      # ─────────────────────────────────────────────────────────────
      [ -f ~/.secrets.zsh ] && source ~/.secrets.zsh
    '';
  };

  # ──────────────────────────────────────────────────────────────
  # Starship prompt
  # ──────────────────────────────────────────────────────────────
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      add_newline = true;
      character = {
        success_symbol = "[➜](bold green)";
      };
      package = {
        disabled = false;
      };
      kubernetes = {
        disabled = false;
      };
    };
  };

  # ──────────────────────────────────────────────────────────────
  # Direnv
  # ──────────────────────────────────────────────────────────────
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # ──────────────────────────────────────────────────────────────
  # Atuin (shell history)
  # ──────────────────────────────────────────────────────────────
  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
  };

  # ──────────────────────────────────────────────────────────────
  # Tmux
  # ──────────────────────────────────────────────────────────────
  programs.tmux = {
    enable = true;
    shell = "${pkgs.zsh}/bin/zsh";
    prefix = "C-t";
    escapeTime = 0;
    baseIndex = 1;
    mouse = true;
    keyMode = "vi";
    terminal = "screen-256color";

    extraConfig = ''
      # enable true color
      set -ga terminal-overrides ",xterm-256color:Tc"

      # pane base index
      set-option -g pane-base-index 1

      # keybindings
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R
      bind -n C-s select-pane -t :.+
      bind | split-window -h -c '#{pane_current_path}'
      bind - split-window -v -c '#{pane_current_path}'
      bind c new-window -c '#{pane_current_path}'
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      # reload config
      bind r source-file ~/.config/tmux/tmux.conf \; display "Reloaded!"

      # vi copy mode
      bind-key -T copy-mode-vi v send -X begin-selection
      bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "pbcopy"
      bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "pbcopy"
      bind-key -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "pbcopy"

      ##################
      #   Appearance   #
      ##################

      # status bar
      set-option -g status-left-length 90
      set-option -g status-right-length 90
      set-option -g status-right '[%Y-%m-%d(%a) %H:%M]'
      set-option -g status-interval 1
      set-option -g status-position top
      set-option -g status-justify left
      set-option -g status-left ' '
      set-option -g status-left-length 10
      set-option -g status-bg "colour238"
      set-option -g status-fg "colour255"

      # base16-gruvbox-dark-pale
      set-option -g status-style "fg=#949494,bg=#3a3a3a"
      set-window-option -g window-status-style "fg=#949494,bg=default"
      set-window-option -g window-status-current-style "fg=#ffaf00,bg=default"
      set-option -g pane-border-style "fg=#4e4e4e,bg=default"
      set-option -g pane-active-border-style "fg=#ffaf00,bg=default,bold"
      set-option -g pane-border-status top
      set-option -g pane-border-format " #P: #{pane_current_command} "
      set-option -g pane-border-lines double
      set-option -g pane-border-indicators arrows
      set-option -g display-panes-active-colour "#afaf00"
      set-option -g display-panes-colour "#ffaf00"
      set-option -g message-style "fg=#dab997,bg=#3a3a3a"
      set-window-option -g clock-mode-colour "#afaf00"
      set-window-option -g mode-style "fg=#949494,bg=#4e4e4e"
      set-window-option -g window-status-bell-style "fg=#3a3a3a,bg=#d75f5f"
    '';
  };
}
