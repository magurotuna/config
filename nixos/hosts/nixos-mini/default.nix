# Machine-specific configuration for nixos-mini
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../common.nix
  ];

  networking.hostName = "nixos-mini";

  # https://nixos.org/nixos/options.html
  system.stateVersion = "25.11";
}
