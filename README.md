# config

Nix flake-based dotfiles managed with
[home-manager](https://github.com/nix-community/home-manager).

## Structure

```
.
├── flake.nix       # Flake definition with multi-machine support
├── flake.lock      # Pinned dependency versions
├── home.nix        # Main home-manager configuration
├── linux.nix       # Linux-specific settings (XDG mime, wl-clipboard)
├── gnome.nix       # GNOME desktop config (xremap, extensions, dconf)
└── nvim/
    └── init.lua    # Neovim config (uses lazy.nvim for plugins)
```

## Machines

| Name               | System         | Description                |
| ------------------ | -------------- | -------------------------- |
| `yusuke@wsl`       | x86_64-linux   | WSL2 on Windows            |
| `yusuke@nixos-mini`| x86_64-linux   | NixOS with GNOME (desktop) |
| `yusuke@macbook`   | aarch64-darwin | Apple Silicon Mac          |

## Prerequisites

### Install Nix

Using the
[Determinate Systems installer](https://docs.determinate.systems/determinate-nix/)
(recommended - flakes enabled by default):

```bash
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

### First-time setup

```bash
# Clone the repo
ghq get https://github.com/magurotuna/config.git
# or
git clone git@github.com:magurotuna/config.git ~/Repo/github.com/magurotuna/config

# Apply configuration (first time - bootstraps home-manager)
nix run home-manager -- switch --flake ~/Repo/github.com/magurotuna/config#yusuke@wsl
```

## Usage

### Apply changes

After editing `home.nix` or other config files:

```bash
home-manager switch --flake .#yusuke@wsl
```

Use `-b backup` if existing files need to be backed up:

```bash
home-manager switch --flake .#yusuke@wsl -b backup
```

### Update dependencies

Update all flake inputs (nixpkgs, home-manager) to latest:

```bash
nix flake update
```

### Search for packages

```bash
nix search nixpkgs <package-name>
```

## What's managed

### Packages

See `home.packages` in `home.nix`. Includes:

- **Core CLI**: ripgrep, fd, eza, bat, fzf, jq, tree, dust, tokei, neofetch
- **Git tools**: gh, ghq, git-lfs, delta, gnupg
- **Shell/terminal**: zellij, ghostty
- **Clipboard**: xsel (X11), wl-clipboard (Wayland)
- **Network**: oha, websocat
- **Kubernetes**: k9s, stern, kubectl, helm, minikube, talosctl
- **Cloud**: awscli2, terraform, google-cloud-sql-proxy, minio, minio-client
- **Databases**: duckdb, redis
- **Languages/tools**: protobuf, typst, ast-grep
- **Load testing**: k6, hey
- **Python**: uv
- **AI**: codex, gemini-cli, claude-code
- **Other**: imagemagick, neovim, codecrafters-cli

### Programs (with config)

| Program             | Description                                            |
| ------------------- | ------------------------------------------------------ |
| `programs.git`      | Git config, GPG signing, credential helpers for GitHub |
| `programs.zsh`      | Shell with aliases, env vars, history settings         |
| `programs.starship` | Prompt with k8s context display                        |
| `programs.tmux`     | Terminal multiplexer with vim keybindings, OSC 52      |
| `programs.ghostty`  | GPU-accelerated terminal with OSC 52 clipboard         |
| `programs.gpg`      | GPG agent with pinentry (curses or gnome3)             |
| `programs.direnv`   | Per-directory environments with nix-direnv             |
| `programs.atuin`    | Shell history sync                                     |

### Config files

| File                      | Source            |
| ------------------------- | ----------------- |
| `~/.config/nvim/init.lua` | `./nvim/init.lua` |

### GNOME desktop (nixos-mini only)

The `gnome.nix` module configures the GNOME desktop environment:

- **xremap**: macOS-like keybindings (Super for app shortcuts, Ctrl for Emacs
  movement, Alt for word navigation), CapsLock remapped to Ctrl
- **GNOME extensions**:
  - quake-terminal: Dropdown terminal toggle (`Ctrl+.`)
  - kimpanel: Input method panel integration
  - xremap: Enables app detection for per-app keybindings
- **ulauncher**: App launcher (`Super+Space`)
- **dconf settings**: Dark theme, wallpaper, keyboard repeat rate

## Secrets

Secrets are stored in `~/.secrets.zsh` (not tracked in git) and sourced by zsh:

```bash
# Example ~/.secrets.zsh
export SOME_API_KEY="..."
export DATABASE_PASSWORD="..."
```

## Notes

### Unfree packages

Terraform has a non-free license (BSL). This is allowed via
`config.allowUnfree = true` in `flake.nix`.

### Zinit

Zsh plugins are managed by [zinit](https://github.com/zdharma-continuum/zinit),
not Nix. This keeps plugin management flexible. Plugins:

- zsh-completions
- fast-syntax-highlighting
- zsh-autosuggestions

### Neovim

Neovim plugins are managed by [lazy.nvim](https://github.com/folke/lazy.nvim),
not Nix. The `lazy-lock.json` is in `~/.config/nvim/` (not tracked).

### Things NOT managed by Nix

- `~/.local/bin/cursor-agent` - Cursor IDE agent (not in nixpkgs)
