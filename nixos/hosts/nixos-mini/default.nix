# Machine-specific configuration for nixos-mini
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../common.nix
    ../../hermes-agent.nix
  ];

  networking.hostName = "nixos-mini";

  # Mosh: roaming, intermittent-connectivity-friendly remote shell.
  # Enabling this installs the mosh package and opens UDP 60000-61000.
  programs.mosh.enable = true;

  # https://nixos.org/nixos/options.html
  system.stateVersion = "25.11";
}
