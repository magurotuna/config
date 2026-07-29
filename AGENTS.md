# AGENTS.md

This file provides guidance to AI coding assistants when working with code in this repository.
`CLAUDE.md` is a symlink to this file.

## Language

Write **English** for everything that lands in this repository: code comments, Nix
option text, Markdown docs, shell script comments, commit messages, PR titles and
descriptions, and branch names. This holds regardless of which language the user
writes in — converse with the user in whatever language they use, but anything
committed is English.

## Project Overview

Nix flake-based dotfiles and system configuration managed with home-manager, NixOS,
and nix-darwin. Supports three machines:
- `yusuke@wsl` (x86_64-linux) - WSL2 on Windows
- `yusuke@nixos-mini` (x86_64-linux) - NixOS desktop with KDE Plasma 6
- `yusuke@macbook` (aarch64-darwin) - Apple Silicon Mac

## Common Commands

```bash
# Apply home-manager changes (user environment; all three machines)
home-manager switch --flake .#yusuke@wsl
home-manager switch --flake .#yusuke@nixos-mini
home-manager switch --flake .#yusuke@macbook

# Apply system changes
sudo nixos-rebuild switch --flake .#nixos-mini   # NixOS (nixos-mini)
sudo darwin-rebuild switch --flake .#macbook     # nix-darwin (macbook)

# Update flake dependencies
nix flake update

# Search for packages
nix search nixpkgs <package-name>
```

Use `-b backup` flag with home-manager if existing files conflict.

## Architecture

```
flake.nix              # Entry point: inputs, overlays, outputs for all machines
├── home.nix           # Base home-manager config (applies to all machines)
├── linux.nix          # Linux-only bits: mime handlers, wl-clipboard
├── kde.nix            # KDE Plasma via plasma-manager + xremap (nixos-mini only)
├── gnome.nix          # Orphaned: pre-KDE desktop config, kept for rollback only
├── darwin.nix         # nix-darwin system layer: macOS defaults + Homebrew
├── nvim/              # Neovim config (init.lua + lua/, lazy.nvim for plugins)
├── claude/skills/     # Agent skills, deployed to ~/.claude/skills and ~/.agents/skills
├── herdr/ cmux/ karabiner/ macos-hotkey/   # App configs deployed by home.nix
├── overlays/          # Prebuilt-binary packages (clawpatrol, clickhouse)
└── nixos/
    ├── common.nix        # Shared NixOS system config
    ├── hermes-agent.nix  # hermes-agent daemon, egress-confined via clawpatrol
    └── hosts/nixos-mini/ # Machine-specific NixOS config
```

**Configuration flow**: `flake.nix` composes each machine's output from a list of modules.

| Machine | home-manager modules |
| ------------------- | ------------------------------------------------------------- |
| `yusuke@wsl`        | `home.nix`                                                    |
| `yusuke@nixos-mini` | `home.nix` + `linux.nix` + `kde.nix` + xremap + plasma-manager |
| `yusuke@macbook`    | `home.nix`                                                    |

macOS is two independent layers: `darwinConfigurations.macbook` (system settings and
Homebrew, needs sudo) and `homeConfigurations."yusuke@macbook"` (user environment, no
sudo). Applying one does not apply the other.

## Key Patterns

- **Plugin management outside Nix**: Zsh plugins via zinit, Neovim plugins via lazy.nvim (not Nix-managed for flexibility)
- **Secrets**: Stored in `~/.secrets.zsh` (not tracked), sourced at shell startup
- **Unfree packages**: Allowed via `config.allowUnfree = true` in flake.nix (e.g. Terraform's BSL license)
- **OSC 52 clipboard**: Used across tmux, ghostty, and neovim for consistent terminal clipboard support
- **xremap**: Provides macOS-like keybindings on Linux (Emacs-style navigation, Alt for word movement); configured in `kde.nix`
- **Deno auto-latest**: An inline overlay in `flake.nix` selects the newest version deno-overlay exposes, so `nix flake update` transparently upgrades deno
- **Prebuilt-binary overlays**: `overlays/` wraps upstream release artifacts instead of building from source (avoids uncached multi-hour builds). Bump clawpatrol with `./update-clawpatrol.sh <version>`; clickhouse is hand-pinned
- **Agent skills single-sourced**: `claude/skills/<name>/` is deployed to both `~/.claude/skills` (Claude) and `~/.agents/skills` (Codex) by `home.nix`. Deployment is *not* automatic — add the name to the `verbatimSkills` list in `home.nix` and `git add` the files, or the flake never sees the skill. `output-learn` is the exception: it needs per-machine substitution, so it is generated separately and must stay out of `verbatimSkills`
- **Read-only vs writable config**: Most app configs are `xdg.configFile` store symlinks; `cmux` rewrites its config at runtime, so `home.nix` installs a writable copy via an activation script instead

## When Making Changes

- User environment changes go in `home.nix` (or `linux.nix`/`kde.nix` for Linux/KDE, `darwin.nix` for macOS system settings)
- NixOS system changes go in `nixos/common.nix` or `nixos/hosts/<hostname>/`
- Commit `flake.lock` after running `nix flake update`
- Consider which machines are affected when modifying shared configs — `home.nix` hits all three
