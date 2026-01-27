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
  };

  outputs = { nixpkgs, home-manager, xremap, claude-code-overlay, ... }:
    let
      mkPkgs = system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ claude-code-overlay.overlays.default ];
      };
    in
    {
      # NixOS system configurations
      nixosConfigurations = {
        nixos-mini = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./nixos/hosts/nixos-mini ];
        };
      };

      # Standalone home-manager configurations (separate from NixOS)
      homeConfigurations = {
        "yusuke@wsl" = home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs "x86_64-linux";
          extraSpecialArgs = {
            homeDirectory = "/home/yusuke";
          };
          modules = [ ./home.nix ];
        };

        "yusuke@nixos-mini" = home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs "x86_64-linux";
          extraSpecialArgs = {
            homeDirectory = "/home/yusuke";
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
          };
          modules = [ ./home.nix ];
        };
      };
    };
}
