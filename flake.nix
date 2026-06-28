{
  description = "Yusuke's dotfiles";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    xremap = {
      url = "github:xremap/nix-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-code-overlay = {
      url = "github:ryoppippi/claude-code-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    codex-cli-nix = {
      url = "github:sadjow/codex-cli-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    deno-overlay = {
      url = "github:haruki7049/deno-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
};

  outputs = { nixpkgs, home-manager, nix-darwin, xremap, plasma-manager, claude-code-overlay, codex-cli-nix, deno-overlay, ... }:
    let
      denoVersionsOverlay = final: prev:
        let
          # deno-overlay exposes every version under `pkgs.deno.<version>`.
          denoVersions = (deno-overlay.overlays.deno-overlay final prev).deno;
        in
        {
          denoVersions = denoVersions;
        };
      mkPkgs = system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays =
          [
            claude-code-overlay.overlays.default
            (import ./overlays/clawpatrol.nix)
            (import ./overlays/clickhouse.nix)
          ]
          ++ nixpkgs.lib.optional (system == "x86_64-linux") denoVersionsOverlay;
      };
    in
    {
      # NixOS system configurations
      nixosConfigurations = {
        nixos-mini = nixpkgs.lib.nixosSystem {
          modules = [
            { nixpkgs.hostPlatform = "x86_64-linux"; }
            ./nixos/hosts/nixos-mini
          ];
        };
      };

      # Standalone home-manager configurations (separate from NixOS)
      homeConfigurations = {
        "yusuke@wsl" = home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs "x86_64-linux";
          extraSpecialArgs = {
            homeDirectory = "/home/yusuke";
            codexPkg = codex-cli-nix.packages.x86_64-linux.default;
          };
          modules = [ ./home.nix ];
        };

        "yusuke@nixos-mini" = home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs "x86_64-linux";
          extraSpecialArgs = {
            homeDirectory = "/home/yusuke";
            codexPkg = codex-cli-nix.packages.x86_64-linux.default;
          };
          modules = [
            ./home.nix
            ./linux.nix
            ./kde.nix
            xremap.homeManagerModules.default
            plasma-manager.homeModules.plasma-manager
          ];
        };

        "yusuke@macbook" = home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs "aarch64-darwin";
          extraSpecialArgs = {
            homeDirectory = "/Users/yusuke";
            codexPkg = codex-cli-nix.packages.aarch64-darwin.default;
          };
          modules = [ ./home.nix ];
        };
      };

      # macOS system (nix-darwin) — manages system settings + Homebrew only.
      # The user environment is managed separately by the standalone
      # homeConfigurations."yusuke@macbook" above, exactly like nixos-mini.
      #   System changes:  sudo darwin-rebuild switch --flake .#macbook
      #   Home changes:    home-manager switch --flake .#yusuke@macbook   (no sudo)
      darwinConfigurations."macbook" = nix-darwin.lib.darwinSystem {
        modules = [
          {
            nixpkgs.hostPlatform = "aarch64-darwin";
            nixpkgs.config.allowUnfree = true;
          }
          ./darwin.nix
        ];
      };
    };
}
