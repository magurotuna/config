{
  description = "Yusuke's dotfiles";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      mkPkgs = system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
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
