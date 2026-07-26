{ pkgs, lib, homeDirectory, codexPkg, ... }:

let
  tree-sitter-cli = pkgs.rustPlatform.buildRustPackage rec {
    pname = "tree-sitter";
    version = "0.26.3";
    src = pkgs.fetchFromGitHub {
      owner = "tree-sitter";
      repo = "tree-sitter";
      rev = "v${version}";
      hash = "sha256-G1C5IhRIVcWUwEI45ELxCKfbZnsJoqan7foSzPP3mMg=";
    };
    cargoHash = "sha256-kHYLaiCHyKG+DL+T2s8yumNHFfndrB5aWs7ept0X4CM=";
    nativeBuildInputs = [ pkgs.libclang pkgs.pkg-config pkgs.clang ];
    buildInputs = [ pkgs.openssl ];
    LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";
    BINDGEN_EXTRA_CLANG_ARGS = "-isystem ${pkgs.stdenv.cc.libc.dev}/include";
    doCheck = false;  # tests require grammar fixtures
  };
  # mise 2026.6.11's OCI-layer test asserts a setuid bit (mode 0o4755) survives
  # packing, but the Nix build sandbox strips special permission bits, so it sees
  # 0o755 and fails. Skip just that one test; the other ~1349 still run. Remove
  # this override once nixpkgs disables the test upstream. Shadows pkgs.mise via
  # let-over-with, same as tree-sitter-cli above.
  mise = pkgs.mise.overrideAttrs (old: {
    checkFlags = (old.checkFlags or []) ++ [
      "--skip=oci::layer::tests::preserve_metadata_dir_layer_keeps_special_permission_bits"
    ];
  });
  # codex-cli-nix ships `codex` as a launcher that execs the real binary under the
  # name `codex-raw` (its bubblewrap wrapper). herdr identifies the agent in a pane
  # by matching the foreground process name from /proc against a fixed built-in list
  # (…|codex|…); it sees `codex-raw`, never matches, and codex never shows up in
  # herdr's Agents sidebar. herdr treats renamed third-party binaries as out of scope
  # (herdr#1354) and documents the fix: set HERDR_AGENT=<agent>, which the wrapped
  # process inherits and which tells herdr which screen manifest to apply. The hint
  # is a Linux feature since herdr 0.5.10, so this works on the current 0.7.4 — no
  # herdr upgrade needed. symlinkJoin preserves codex-raw and every other file from
  # the package; wrapProgram only rewraps the `codex` entrypoint to inject the var.
  # --set-default so an explicit HERDR_AGENT in the environment still wins.
  codexWrapped = pkgs.symlinkJoin {
    name = "codex-herdr";
    paths = [ codexPkg ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/codex --set-default HERDR_AGENT codex
    '';
  };
  tmuxCopyAction =
    if pkgs.stdenv.isDarwin
    then ''copy-pipe-and-cancel "/usr/bin/pbcopy"''
    else "copy-selection-and-cancel";

  # Compiled Cocoa helper that visibility-toggles an app entirely in-process
  # (NSWorkspace/NSRunningApplication) — no Apple Event round-trip. Invoked from
  # the Karabiner ctrl+. rule in ./karabiner/karabiner.json as a shell_command:
  #   /Users/yusuke/.nix-profile/bin/toggle-app Ghostty
  #
  # The arg is matched against NSRunningApplication.localizedName, case-
  # insensitively, so "Ghostty" matches even though the process is "ghostty".
  #
  # Karabiner (not skhd) owns this hotkey. Originally forced by cmux, which
  # enabled macOS Secure Keyboard Entry while frontmost and so blinded
  # CGEventTap daemons like skhd to the keypress ("secure keyboard entry is
  # enabled by 'cmux'! abort" in skhd's log). Ghostty does not enable SKE by
  # default, but Karabiner is kept: it intercepts at the IOKit HID layer, below
  # SKE, so the hotkey survives if SKE is ever turned on.
  #
  # Added to the darwin home.packages below so it lands at a STABLE profile path
  # (~/.nix-profile/bin/...); karabiner.json is a read-only store symlink and
  # can't interpolate the unstable /nix/store/<hash>/ path. Built from
  # macos-hotkey/toggle-app.m with the stdenv clang; only referenced on darwin.
  toggleAppHelper = pkgs.stdenv.mkDerivation {
    pname = "toggle-app";
    version = "1.0";
    src = ./macos-hotkey;
    dontConfigure = true;
    buildPhase = ''
      runHook preBuild
      $CC -fobjc-arc -Wno-deprecated-declarations -O2 \
        -framework AppKit -framework Foundation \
        -o toggle-app toggle-app.m
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      install -Dm755 toggle-app $out/bin/toggle-app
      runHook postInstall
    '';
  };

  # ── Claude Code / Codex skills ──────────────────────────────────────────────
  # Single-sourced from ./claude/skills/<name>/. Every skill is deployed to BOTH
  # the Claude dir (~/.claude/skills) and the Codex dir (~/.agents/skills) so the
  # two agents share one definition — add a name to `verbatimSkills` and it lands
  # in both. Whole-directory sources also pick up any references/ subfolder.
  # New files must be `git add`ed for the flake to see them.
  skillTargets = [ ".claude/skills" ".agents/skills" ];

  # Skills copied byte-for-byte. output-learn is intentionally NOT listed here: it
  # needs @homeDirectory@ substituted per machine, so it is generated separately.
  verbatimSkills = [
    "dig"
    "smart-compact"
    "plan-refine"
    "plan-review"
    "standup"
    "git-worktree"
    "publish-research-artifact"
  ];

  outputLearnText =
    builtins.replaceStrings [ "@homeDirectory@" ] [ homeDirectory ]
      (builtins.readFile ./claude/skills/output-learn/SKILL.md);

  # Produces { "<target>/<name>".source = ./claude/skills/<name>; ... } for every
  # (target, skill) pair, plus the substituted output-learn SKILL.md per target.
  skillFiles =
    builtins.listToAttrs (lib.concatMap
      (base: map
        (name: {
          name = "${base}/${name}";
          value.source = ./claude/skills + "/${name}";
        })
        verbatimSkills)
      skillTargets)
    // builtins.listToAttrs (map
      (base: {
        name = "${base}/output-learn/SKILL.md";
        value.text = outputLearnText;
      })
      skillTargets);
in
lib.mkMerge [
{
  home.file = skillFiles;
}
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

  # herdr (all machines). Read-only symlink like nvim above — herdr only reads
  # config.toml, so no writable-seed hack (cf. cmux). Keybinds mirror tmux/cmux;
  # edit ./herdr/config.toml + `home-manager switch`, then `herdr server
  # reload-config`. Validate edits with `herdr config check`.
  xdg.configFile."herdr/config.toml".source = ./herdr/config.toml;

  # Karabiner-Elements (macOS only). Declarative config: edit
  # ./karabiner/karabiner.json in this repo and `home-manager switch`.
  # NOTE: this deploys a read-only symlink into the Nix store, so the
  # Karabiner GUI can no longer save changes — manage keybinds here instead.
  xdg.configFile."karabiner/karabiner.json" =
    lib.mkIf pkgs.stdenv.isDarwin { source = ./karabiner/karabiner.json; };

  # cmux terminal (macOS only). tmux-style `C-t` prefix chords so the muscle
  # memory from programs.tmux below carries over to cmux's native splits/tabs
  # (which is what keeps its per-surface agent progress tracking working).
  # Action IDs verified against cmux docs; edit ./cmux/cmux.json + `home-manager switch`.
  #
  # NOT xdg.configFile (read-only store symlink): cmux re-saves this file on
  # launch via atomic write-and-rename, which replaces the symlink with a fresh
  # default template and wipes our bindings. Instead seed a *writable* copy cmux
  # can read and re-own. Overwrite on every switch (unlike seedGhosttyOverrides'
  # seed-if-missing) so the repo stays the source of truth and a clobbered file
  # self-heals; cmux.json is an override layer, so keys we omit fall back to
  # cmux's own Settings store.
  home.activation.seedCmuxConfig = lib.mkIf pkgs.stdenv.isDarwin (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      dest="${homeDirectory}/.config/cmux/cmux.json"
      mkdir -p "$(dirname "$dest")"
      install -m600 ${./cmux/cmux.json} "$dest"
    ''
  );

  # NOTE: the ctrl+. "toggle Ghostty" hotkey is defined in ./karabiner/karabiner.json
  # (a shell_command manipulator calling toggle-app), NOT here. skhd used to
  # own it but cmux's Secure Keyboard Entry made skhd's event tap permanently
  # blind to the keypress — see the toggleAppHelper comment above for details.

  # Clawpatrol.app (macOS only). The clawpatrol CLI is a normal Nix package in
  # home.packages; but `clawpatrol run` also needs Clawpatrol.app installed in
  # /Applications, because it hosts the NetworkExtension system extension that
  # intercepts per-process flows. macOS validates and activates a system
  # extension from a real bundle in /Applications, so a Nix store symlink won't
  # do — we copy the store-staged bundle in, exactly like install.sh does.
  #
  # This is an imperative side effect outside the Nix store: it is NOT rolled
  # back on generation switch and NOT garbage-collected. Removing this block
  # won't uninstall the app — `sudo rm -rf /Applications/Clawpatrol.app` for that.
  # Activating the system extension itself is still a one-time manual step:
  # run `clawpatrol run`, then approve it in System Settings > Privacy & Security
  # (and allow the network filter). install.sh doesn't automate that either.
  home.activation.clawpatrolApp = lib.mkIf pkgs.stdenv.isDarwin (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      src="${pkgs.clawpatrol-app}/Applications/Clawpatrol.app"
      dest="/Applications/Clawpatrol.app"
      # Only touch /Applications when the bundle actually differs, so routine
      # `home-manager switch` runs stay no-ops.
      if [ ! -e "$dest" ] || ! /usr/bin/diff -rq "$src" "$dest" >/dev/null 2>&1; then
        $DRY_RUN_CMD rm -rf "$dest"
        $DRY_RUN_CMD cp -R "$src" "$dest"
        # Store copy is read-only (0444/0555); make the installed bundle
        # writable so a later rm/refresh doesn't need sudo. Does not affect
        # the code signature.
        $DRY_RUN_CMD chmod -R u+w "$dest"
      fi
    ''
  );

  # ──────────────────────────────────────────────────────────────
  # Claude Code
  # ──────────────────────────────────────────────────────────────
  home.file.".claude/settings.json".text = ''
    {
      "statusLine": {
        "type": "command",
        "command": "${homeDirectory}/.claude/statusline-command.sh"
      },
      "enabledPlugins": {
        "rust-analyzer-lsp@claude-plugins-official": false,
        "code-simplifier@claude-plugins-official": true,
        "gopls-lsp@claude-plugins-official": true,
        "typescript-lsp@claude-plugins-official": true
      },
      "permissions": {
        "defaultMode": "auto",
        "allow": [
          "Bash(gh search:*)",
          "Bash(gh api:*)"
        ]
      },
      "alwaysThinkingEnabled": true,
      "effortLevel": "high",
      "advisorModel": "fable",
      "remoteControlAtStartup": true,
      "plansDirectory": "./plans",
      "outputStyle": "Explanatory",
      "hooks": {
        "Stop": [
          {
            "hooks": [
              {
                "type": "command",
                "command": "pw-play ${homeDirectory}/.local/share/sounds/claude-done.oga 2>/dev/null || afplay /System/Library/Sounds/Glass.aiff 2>/dev/null || true"
              }
            ]
          }
        ],
        "Notification": [
          {
            "hooks": [
              {
                "type": "command",
                "command": "pw-play ${homeDirectory}/.local/share/sounds/claude-notification.oga 2>/dev/null || afplay /System/Library/Sounds/Ping.aiff 2>/dev/null || true"
              }
            ]
          }
        ]
      }
    }
  '';
  # Sound files for Claude Code hooks (Linux only; macOS uses built-in sounds).
  # mkIf on the whole entry keeps it (and the Linux-only package reference) off
  # darwin entirely, where the hooks fall back to afplay.
  home.file.".local/share/sounds/claude-done.oga" = lib.mkIf pkgs.stdenv.isLinux {
    source = "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/service-login.oga";
  };
  home.file.".local/share/sounds/claude-notification.oga" = lib.mkIf pkgs.stdenv.isLinux {
    source = "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/complete.oga";
  };

  # `codex remote-control start` refuses to run unless it finds a binary at the
  # fixed path ~/.codex/packages/standalone/current/codex — the daemon respawns and
  # auto-updates app-server from there, so it only accepts the mutable install laid
  # down by the curl|sh installer and bails with "managed standalone Codex install
  # not found at …" otherwise. Nothing about that path is nix-installable: the store
  # is read-only and the installer would have to own $HOME. Symlinking the wrapped
  # package into the expected layout satisfies the check and the daemon then runs
  # the exact same binary as the one on PATH (verified: daemon reports version
  # 0.145.0, and its updater leaves these links alone). The tradeoff is that codex
  # can no longer self-update the daemon — which is what we want, since the version
  # is pinned by codex-cli-nix in flake.nix anyway.
  home.file.".codex/packages/standalone/current/codex".source = "${codexWrapped}/bin/codex";
  home.file.".codex/packages/standalone/current/codex-raw".source = "${codexWrapped}/bin/codex-raw";
  home.file.".codex/packages/standalone/current/codex-code-mode-host".source = "${codexWrapped}/bin/codex-code-mode-host";

  home.file.".claude/agents/codex-reviewer.md".text = ''
    ---
    name: codex-reviewer
    description: Delegate code review to Codex CLI in headless mode
    ---

    You are a review orchestrator that delegates code review to OpenAI Codex CLI (`codex exec`) in headless mode.

    ## Overview

    You do NOT review the code yourself. Instead, you:

    1. Determine the review target from the user's request
    2. Invoke `codex exec review` to get Codex's review
    3. Present the results as-is

    ## Execution Flow

    ### Phase 1: Determine Review Target

    Based on the user's request, decide the appropriate review mode:

    - **Default (current branch vs base)**: Review changes on the current branch against the default base branch.
    - **Uncommitted changes**: If the user asks to review uncommitted / staged / working tree changes, use `--uncommitted`.
    - **Specific base branch**: If the user specifies a base branch, use `--base <branch>`.
    - **Specific commit**: If the user specifies a commit SHA, use `--commit <sha>`.

    ### Phase 2: Codex Exec Invocation

    Run `codex exec review` in headless mode with `--sandbox read-only`.

    Examples:

    ```bash
    # Review current branch changes
    codex exec review --sandbox read-only

    # Review uncommitted changes
    codex exec review --sandbox read-only --uncommitted

    # Review against a specific base branch
    codex exec review --sandbox read-only --base main

    # Review a specific commit
    codex exec review --sandbox read-only --commit abc1234
    ```

    If the user provides additional review instructions, pass them as the prompt argument:

    ```bash
    codex exec review --sandbox read-only "Focus on error handling and security"
    ```

    **Important**:
    - Set a generous timeout (up to 600 seconds)
    - Do NOT use the `-m` option — let Codex use its default model
    - `--sandbox read-only` ensures safe read-only file access

    ### Phase 3: Result Presentation

    Present the stdout output from Codex CLI as-is. Do not add edits or interpretation.
    If `codex exec` fails, report the exit code and stderr content.

    ## Error Handling

    | Situation               | Response                                   |
    | ----------------------- | ------------------------------------------ |
    | codex command not found | Guide user to install the `codex` CLI      |
    | codex exec timeout      | Report the timeout and suggest retry       |
    | Authentication error    | Guide user to verify API key configuration |
    | Empty stdout            | Report the codex exec exit code            |

    ## Notes

    - The actual review is performed by Codex CLI — this agent only handles orchestration
    - Uses stdin/stdout — no temporary files needed
  '';

  # ── Claude Code / Codex skills ──
  # Deployed by the generated `skillFiles` set in the `let` block above (merged
  # via lib.mkMerge at the top of this module). Both agents read the same source:
  # Claude from ~/.claude/skills, Codex from ~/.agents/skills (personal Codex
  # skills are discovered there; Codex custom prompts are deprecated). To add a
  # skill, drop it in ./claude/skills/<name>/ and add <name> to `verbatimSkills`.

  home.file.".claude/statusline-command.sh" = {
    executable = true;
    text = ''
      #!/bin/bash

      # Read JSON input
      input=$(cat)

      # Extract current directory from JSON
      cwd=$(echo "$input" | jq -r '.workspace.current_dir')

      # Get username
      user=$(whoami)

      # Get hostname (short form)
      host=$(hostname -s)

      # Get current directory (use basename for short form, or full path)
      current_dir="$cwd"

      # Get git branch if in a git repository
      git_branch=""
      if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
          # Skip optional locks to avoid blocking
          branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
          if [ -n "$branch" ]; then
              git_branch=" ($branch)"
          fi
      fi

      # Format the output with colors (using printf for ANSI codes)
      # Note: Colors will be dimmed by Claude Code
      printf "\033[01;32m%s@%s\033[00m:\033[01;34m%s\033[00m%s" "$user" "$host" "$current_dir" "$git_branch"
    '';
  };

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
    fastfetch
    htop
    openssl
    unzip

    # Git tools
    ghq
    git-lfs
    delta
    gnupg
    lazygit

    # Network / HTTP
    dnsutils
    nghttp2
    oha
    websocat
    tailscale

    # Kubernetes
    k9s
    stern
    kubectl
    kubernetes-helm
    (lib.lowPrio minikube) # Prefer the standalone kubectl over minikube's kubectl symlink.
    talosctl

    # Cloud / Infrastructure
    awscli2
    terraform
    google-cloud-sdk
    google-cloud-sql-proxy
    minio-client

    # Databases
    duckdb
    postgresql
    redis

    # Languages / Build tools
    lld
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
    go

    # Language servers
    lua-language-server
    typescript-language-server
    rust-analyzer
    gopls
    pyright
    # it's somehow broken now on Feb 11 2026
    # zls

    # File watching
    watchman

    # Other
    imagemagick
    sox

    # Load testing
    k6
    hey

    # Python
    python3
    uv

    # Learning
    codecrafters-cli

    # AI
    codexWrapped # codexPkg (codex-cli-nix), wrapped to set HERDR_AGENT=codex for herdr detection
    gemini-cli
    claude-code
    clawpatrol # security firewall for agents; overlays/clawpatrol.nix
    herdr      # agent multiplexer for the terminal (nixpkgs)

    # Git worktree
    git-wt

    # Shell enhancements (migrated from brew)
    atuin          # shell history with sync
    direnv         # per-directory env vars
    starship       # cross-shell prompt

    # CLI tools (migrated from brew)
    cmake
    findutils      # GNU find/xargs (gfind, gxargs on darwin)
    git-filter-repo
    gnused         # GNU sed (available as gsed on darwin)
    hyperfine      # benchmarking
    jnv            # interactive jq TUI
    mosh           # mobile shell
    silicon        # code screenshot (source → image)
    watch          # watch command
    wget

    # GitHub CLI
    gh

    # Databases (migrated from brew). clickhouse: prebuilt client binary on
    # darwin (server runs in Docker), nixpkgs build on Linux; see
    # overlays/clickhouse.nix.
    clickhouse
    # NOTE: postgresql NOT migrated as v14 — `postgresql` (v17) is already in
    # home.packages above; can't have two versions (pg_rewind etc. collide).
    # If a project needs PG14 specifically, keep `postgresql@14` in brew.
    # NOTE: minio (server) intentionally NOT migrated — nixpkgs marks it
    # insecure (abandoned upstream, unpatched CVEs). Kept in Homebrew.

    # Network
    ngrok

    # Kubernetes
    kubectx

    # Build tools / Java
    maven
    cargo-make

    # Runtime version managers (migrated from brew)
    volta
    mise
  ] ++ lib.optionals pkgs.stdenv.isLinux [
    tree-sitter-cli  # custom build (0.26.x for nvim-treesitter); see let-binding above

    gcc  # on macOS the native clang from stdenv is used instead

    # Clipboard (X11 / Wayland)
    xsel
    wl-clipboard

    # GUI apps. On macOS these come from Homebrew casks (see darwin.nix),
    # because nixpkgs has no (or no reliable) darwin build for them.
    google-chrome
    discord
    slack
    vscode
    zed-editor
    obs-studio
    gradia
  ] ++ lib.optionals pkgs.stdenv.isDarwin [
    tree-sitter  # nixpkgs CLI (the custom 0.26.x build above is Linux-only for now)

    # In-process app visibility toggler, invoked by the Karabiner ctrl+. rule.
    # Here (not just as a let-binding) so it gets a stable ~/.nix-profile path
    # that karabiner.json can hardcode. See toggleAppHelper above.
    toggleAppHelper

    # macOS-specific pinentry for GPG (integrates with macOS Keychain)
    pinentry_mac

    # Fonts (replaces brew cask font-jetbrains-mono-nerd-font)
    nerd-fonts.jetbrains-mono

    # GUI apps / tools with nixpkgs darwin builds (migrated from brew casks)
    _1password-cli
    wezterm

    # On NixOS this comes from nixos/common.nix's fonts.packages; darwin needs it via home-manager.
    (pkgs.google-fonts.override { fonts = [ "Google Sans Code" ]; })
  ];

  # ──────────────────────────────────────────────────────────────
  # Git
  # ──────────────────────────────────────────────────────────────
  programs.git = {
    enable = true;
    signing.format = "openpgp";

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
      # Some frameworks use a literal "~" directory in route paths.
      # Keep backup-file ignores, but unignore "~" directories and their contents.
      "!**/~/"
      "!**/~/**"
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

    signing = {
      # Don't specify the signing key so that git will look up a key maching the email
      # key = "do-not-comment-out";
      signByDefault = true;
    };

    settings = {
      init.defaultBranch = "main";
      wt = {
        basedir = "../{gitroot}-wt";
        copyignored = true;
        copyuntracked = true;
      };
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
  # GitHub CLI
  # ──────────────────────────────────────────────────────────────
  programs.gh = {
    enable = true;
    extensions = [ pkgs.gh-markdown-preview ];
  };

  # ──────────────────────────────────────────────────────────────
  # Zsh
  # ──────────────────────────────────────────────────────────────
  programs.zsh = {
    enable = true;
    enableCompletion = false; # We call compinit manually after zinit loads completions

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

      # Deno (same as `deno x --install-alias`, but in a nix friendly way)
      dx = "deno x";


      # Deno Deploy environments
      local_deployctl = "DENO_TLS_CA_STORE=system DEPLOY_API_ENDPOINT=\"https://deno-local.com\" deployctl";
      dev_deployctl = "DEPLOY_API_ENDPOINT=\"https://dash.deno-dev.com\" deployctl";
      staging_deployctl = "DEPLOY_API_ENDPOINT=\"https://deno-staging.com\" deployctl";
    };

    # Raw zsh configuration
    initContent = lib.mkMerge [
      ''
      # Additional shell options
      setopt no_global_rcs
      setopt AUTO_PARAM_KEYS

      # zsh-autosuggestions searches zsh's in-memory history, while Home
      # Manager sets HISTFILE after zsh's startup history import point.
      # Import the persistent history before loading autosuggestions so fresh
      # terminals can suggest commands from previous sessions.
      [[ -r "$HISTFILE" ]] && fc -R "$HISTFILE" 2>/dev/null || true

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

      ${lib.optionalString pkgs.stdenv.isLinux ''
        # Clipboard (auto-detect X11 vs Wayland)
        if [[ -n "$WAYLAND_DISPLAY" ]]; then
          pbcopy() { printf '\e]52;c;'; base64 -w0; printf '\a'; }
          # Avoid wl-copy because it causes a terminal window opened by quake-terminal (GNOME extension) to disappear
          alias pbpaste='xsel --clipboard --output | tr -d "\r"'
          alias pbcopy-wl='wl-copy'
          alias pbpaste-wl='wl-paste'
        else
          alias pbcopy='xsel --clipboard --input'
          alias pbpaste='xsel --clipboard --output | tr -d "\r"'
        fi
      ''}

      # Library path for native npm modules (e.g., @parcel/watcher) - Linux only.
      # Guarded in Nix (not just at runtime) so pkgs.stdenv.cc.cc.lib is never
      # forced on darwin, where that output doesn't exist.
      ${lib.optionalString pkgs.stdenv.isLinux ''
        export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib:''${LD_LIBRARY_PATH:-}"
      ''}

      # Homebrew (kept for GUI casks during/after the Nix migration). Note this
      # prepends /opt/homebrew/bin, so during migration a brew copy can shadow
      # the Nix one for duplicated tools — uninstall the brew copy to let Nix win.
      ${lib.optionalString pkgs.stdenv.isDarwin ''
        eval "$(/opt/homebrew/bin/brew shellenv)"
      ''}

      # Additional PATH entries
      export PATH="/usr/local/bin:$HOME/bin:$PATH"
      export PATH="$HOME/go/bin:$PATH"
      export PATH="$HOME/.local/bin:$PATH"
      export PATH="/snap/bin:$PATH"

      # uv (Python) completions - cached for speed
      () {
        local cache="''${XDG_DATA_HOME:-$HOME/.local/share}/zsh/uv-completion.zsh"
        local uv_bin="${pkgs.uv}/bin/uv"
        if [[ ! -f $cache || $uv_bin -nt $cache ]]; then
          mkdir -p "''${cache:h}"
          "$uv_bin" generate-shell-completion zsh > "$cache"
        fi
        source "$cache"
      }


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

      # Completions (compinit runs synchronously; plugins deferred via turbo mode)
      autoload -Uz compinit
      compinit -C

      zinit ice wait lucid blockf atpull'zinit creinstall -q .'
      zinit light zsh-users/zsh-completions

      # fzf-tab (must be loaded after compinit, before autosuggestions/syntax-highlighting)
      zinit ice wait lucid
      zinit light Aloxaf/fzf-tab

      # Syntax highlighting and autosuggestions
      zinit ice wait lucid
      zinit light zdharma-continuum/fast-syntax-highlighting
      # atload'!_zsh_autosuggest_start' is required when loading autosuggestions
      # under turbo (wait): otherwise the plugin sources after the first prompt's
      # precmd has run, its widget hooks never bind, and the inline "shadow"
      # suggestions never appear. atload runs the start function right after load.
      zinit ice wait lucid atload'!_zsh_autosuggest_start'
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
      ''
      (lib.mkOrder 1500 ''
        # Atuin prepends its own autosuggestion strategy, which bypasses zsh's
        # in-memory history. Keep Atuin widgets, but make inline suggestions use
        # the history imported above.
        if [[ $options[zle] = on ]]; then
          ZSH_AUTOSUGGEST_STRATEGY=(history)
          (( $+functions[_zsh_autosuggest_start] )) && _zsh_autosuggest_start
        fi
      '')
      (lib.mkIf pkgs.stdenv.isDarwin ''
        # cmux uses libghostty as its rendering engine and turns on the kitty
        # keyboard protocol's "disambiguate" flag at the PTY level, with no option
        # to disable it (cmux#3837). Unlike the Linux setup there is no tmux layer
        # to shield the shell, so Ctrl+M / Ctrl+I / Ctrl+[ arrive as CSI-u
        # sequences instead of their legacy bytes, so Ctrl+M stops acting as Enter
        # and Ctrl+[ stops acting as Esc. Map the leaked sequences back to their
        # legacy meaning. These are no-ops whenever the protocol is inactive (the
        # sequences never arrive), so they are safe to set unconditionally on
        # macOS. Ctrl+[ uses `bindkey -s` to re-inject a real Esc byte because Esc
        # is a Meta prefix in our emacs keymap, not a single widget.
        bindkey '\e[109;5u' accept-line   # Ctrl+M (kitty CSI-u) -> Enter
        bindkey -s '\e[91;5u' '\e'        # Ctrl+[ (kitty CSI-u) -> Esc (Meta prefix)
      '')
      (lib.mkOrder 1550 ''
        # Ghostty shell integration, hardened. We disable the home-manager
        # ghostty module's own injection (programs.ghostty.enableZshIntegration
        # = false) because its guard only checks that GHOSTTY_RESOURCES_DIR is
        # set, not that the script exists. cmux renders with libghostty and sets
        # that var to its app bundle (.../cmux.app/Contents/Resources/ghostty),
        # which ships no shell-integration script, so the unguarded `source`
        # errored on every new tab. Add a `-r` file check: real Ghostty loads
        # integration, cmux/other libghostty hosts silently skip it.
        if [[ -n $GHOSTTY_RESOURCES_DIR \
              && -r "$GHOSTTY_RESOURCES_DIR/shell-integration/zsh/ghostty-integration" ]]; then
          source "$GHOSTTY_RESOURCES_DIR/shell-integration/zsh/ghostty-integration"
        fi
      '')
    ];
  };

  # ──────────────────────────────────────────────────────────────
  # SSH
  # ──────────────────────────────────────────────────────────────
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "github.com" = {
        IdentityFile = "~/.ssh/id_ed25519_github";
      };
      "github.com-magurobot" = {
        HostName = "github.com";
        User = "git";
        IdentityFile = "~/.ssh/magurobot_auth";
        IdentitiesOnly = true;
      };
      "codeberg.org" = {
        IdentityFile = "~/.ssh/id_ed25519_codeberg";
      };
      "avocet.deno.co" = {
        IdentityFile = "~/.ssh/id_ed25519_avocet";
      };
    };
  };

  # ──────────────────────────────────────────────────────────────
  # GPG
  # ──────────────────────────────────────────────────────────────
  programs.gpg.enable = true;
  # home-manager's gpg-agent service is systemd-based, so it's Linux-only. On
  # macOS gpg-agent is started on demand; set `pinentry-program` in
  # ~/.gnupg/gpg-agent.conf (e.g. pkgs.pinentry_mac) if you want a GUI prompt.
  services.gpg-agent = lib.mkIf pkgs.stdenv.isLinux {
    enable = true;
    # Set a default pinentry here. Use pinentry-curses unless another module overrides it.
    pinentry.package = lib.mkDefault pkgs.pinentry-curses;

    # Both are needed: maxCacheTtl is an absolute cap (default 7200s) that
    # evicts the key regardless of defaultCacheTtl's sliding idle window.
    defaultCacheTtl = 86400;
    maxCacheTtl = 86400;
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
    settings = {
      enter_accept = false;
      invert = true;
    };
  };

  # ──────────────────────────────────────────────────────────────
  # Ghostty
  # ──────────────────────────────────────────────────────────────
  programs.ghostty = {
    enable = true;
    # nixpkgs has no macOS build of ghostty, so on darwin install it via the
    # Homebrew cask and let home-manager manage only the config file.
    package = if pkgs.stdenv.isDarwin then null else pkgs.ghostty;
    # Replaced by a file-existence-guarded `source` in programs.zsh.initContent
    # above: the module's injection only checks that GHOSTTY_RESOURCES_DIR is
    # set, which breaks under cmux (libghostty sets the var but ships no script).
    enableZshIntegration = false;
    settings = {
      font-family = [
        "JetBrainsMono Nerd Font"
        "Noto Sans Mono CJK JP"
        "Adwaita Mono"
      ];
      theme = "Dracula";
      cursor-style = "block";
      background-opacity = 0.85;
      window-padding-x = 8;
      gtk-tabs-location = "hidden";
      keybind = [
        "ctrl+enter=text:\\n"
        "shift+enter=text:\\n"
      ];
      # Allow interacting with clipboard through OSC 52
      clipboard-read = "allow";
      clipboard-write = "allow";
      app-notifications = "no-clipboard-copy";
      shell-integration-features = "no-cursor";
      # macOS-only: don't persist window state, so macOS won't auto-relaunch
      # Ghostty at login (its "Reopen windows" restoration). No-op on Linux.
      window-save-state = "never";
      # `?` prefix = optional: Ghostty won't error if the local override file
      # is absent. On macOS we seed this file below, but keep it mutable.
      config-file = [
        "?~/.config/ghostty/overrides"
      ];
    } // lib.optionalAttrs (!pkgs.stdenv.isDarwin) {
      font-size = 10;
    };
  };

  home.activation.seedGhosttyOverrides = lib.mkIf pkgs.stdenv.isDarwin (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      overrides="${homeDirectory}/.config/ghostty/overrides"
      if [[ ! -s "$overrides" ]]; then
        mkdir -p "$(dirname "$overrides")"
        cat > "$overrides" <<'EOF'
font-size = 13
EOF
      fi
    ''
  );

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
    terminal = "tmux-256color";

    extraConfig = ''
      # enable true color
      set -g terminal-overrides "xterm-256color:Tc"
      # OSC52 clipboard. `%p2%s` is the base64-encoded selection payload.
      set -ga terminal-overrides ",*:Ms=\E]52;c;%p2%s\007"
      # Cursor shape passthrough (Ss=set style, Se=reset to terminal default)
      set -ga terminal-overrides ",*:Ss=\\E[%p1%d q:Se=\\E[ q"

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

      # OSC52 clipboard
      set-option -s set-clipboard on
      ${lib.optionalString pkgs.stdenv.isDarwin ''
        set-option -s copy-command "/usr/bin/pbcopy"
      ''}

      # vi copy mode
      bind-key -T copy-mode-vi v send -X begin-selection
      bind-key -T copy-mode-vi y send-keys -X ${tmuxCopyAction}
      bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X ${tmuxCopyAction}
      bind-key -T copy-mode-vi Enter send-keys -X ${tmuxCopyAction}

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
]
