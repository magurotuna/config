{
  description = "Yusuke's dotfiles";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
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
    octorus-src = {
      url = "github:ushironoko/octorus/v0.3.1";
      flake = false;
    };
  };

  outputs = { nixpkgs, home-manager, xremap, claude-code-overlay, codex-cli-nix, octorus-src, ... }:
    let
      mkPkgs = system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ claude-code-overlay.overlays.default ];
      };
      mkOctorus = pkgs: pkgs.rustPlatform.buildRustPackage {
        pname = "octorus";
        version = "0.3.1";
        src = octorus-src;
        cargoLock.lockFile = "${octorus-src}/Cargo.lock";
        nativeBuildInputs = [ pkgs.pkg-config ];
        buildInputs = [ pkgs.openssl ];
        doCheck = false;
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
            octorusPkg = mkOctorus (mkPkgs "x86_64-linux");
          };
          modules = [ ./home.nix ];
        };

        "yusuke@nixos-mini" = home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs "x86_64-linux";
          extraSpecialArgs = {
            homeDirectory = "/home/yusuke";
            codexPkg = codex-cli-nix.packages.x86_64-linux.default;
            octorusPkg = mkOctorus (mkPkgs "x86_64-linux");
          };
          modules = [
            ./home.nix
            ./linux.nix
            ./gnome.nix
            xremap.homeManagerModules.default
          ];
        };

        "yusuke@macbook" = home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs "aarch64-darwin";
          extraSpecialArgs = {
            homeDirectory = "/Users/yusuke";
            codexPkg = codex-cli-nix.packages.aarch64-darwin.default;
            octorusPkg = mkOctorus (mkPkgs "aarch64-darwin");
          };
          modules = [ ./home.nix ];
        };
      };
    };
}
