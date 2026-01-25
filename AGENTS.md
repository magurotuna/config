# AGENTS.md

This file provides guidance to AI coding assistants when working with code in this repository.

## Project Overview

Nix flake-based dotfiles and system configuration managed with home-manager and NixOS. Supports three machines:
- `yusuke@wsl` (x86_64-linux) - WSL2 on Windows
- `yusuke@nixos-mini` (x86_64-linux) - NixOS desktop with GNOME
- `yusuke@macbook` (aarch64-darwin) - Apple Silicon Mac

## Common Commands

```bash
# Apply home-manager changes
home-manager switch --flake .#yusuke@wsl
home-manager switch --flake .#yusuke@nixos-mini
home-manager switch --flake .#yusuke@macbook

# Apply NixOS system changes (nixos-mini only)
sudo nixos-rebuild switch --flake .#nixos-mini

# Update flake dependencies
nix flake update

# Search for packages
nix search nixpkgs <package-name>
```

Use `-b backup` flag with home-manager if existing files conflict.

## Architecture

```
flake.nix           # Entry point: defines inputs and outputs for all machines
├── home.nix        # Base home-manager config (applies to all machines)
├── linux.nix       # Linux-specific overrides (wsl, nixos-mini)
├── gnome.nix       # GNOME desktop config (nixos-mini only: xremap, extensions)
├── nvim/init.lua   # Neovim config (lazy.nvim for plugins)
└── nixos/
    ├── common.nix  # Shared NixOS system config
    └── hosts/nixos-mini/  # Machine-specific NixOS config
```

**Configuration flow**: `flake.nix` composes machine-specific outputs by importing the appropriate modules. Each machine profile selects which modules to include (e.g., nixos-mini imports home.nix + linux.nix + gnome.nix).

## Key Patterns

- **Plugin management outside Nix**: Zsh plugins via zinit, Neovim plugins via lazy.nvim (not Nix-managed for flexibility)
- **Secrets**: Stored in `~/.secrets.zsh` (not tracked), sourced at shell startup
- **Unfree packages**: Terraform (BSL license) allowed via `config.allowUnfree = true` in flake.nix
- **OSC 52 clipboard**: Used across tmux, ghostty, and neovim for consistent terminal clipboard support
- **xremap**: Provides macOS-like keybindings on Linux (Emacs-style navigation, Alt for word movement)

## When Making Changes

- User environment changes go in `home.nix` (or `linux.nix`/`gnome.nix` for platform-specific)
- NixOS system changes go in `nixos/common.nix` or `nixos/hosts/<hostname>/`
- Commit `flake.lock` after running `nix flake update`
- Consider which machines are affected when modifying shared configs
