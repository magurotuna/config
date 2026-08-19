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

  # Keep Nix builds from starving the interactive path.
  #
  # This host is reached over SSH via Wi-Fi (enp1s0 is unused) and Tailscale,
  # so both ksoftirqd and userspace tailscaled need timely CPU. A `home-manager
  # switch` that hits an uncached derivation used to saturate all 16 cores
  # (max-jobs = 16 with cores = 0 means up to 16 jobs x 16 threads), which
  # delays packet processing enough to drop the SSH session.
  #
  # Weights alone are not enough: they arbitrate between runnable cgroups, but
  # softirq work lives outside that hierarchy. The hard CPUQuota is what
  # guarantees spare capacity. Builds still run at full speed on an idle box —
  # they are only throttled under contention.
  nix.daemonCPUSchedPolicy = "batch"; # like "other", tuned for non-interactive work
  nix.daemonIOSchedClass = "idle";

  systemd.services.nix-daemon.serviceConfig = {
    CPUWeight = 20; # vs. the default 100 of every other service
    IOWeight = 20;
    CPUQuota = "1400%"; # leave ~2 of 16 cores free at all times
  };

  # SSH here rides Tailscale, and tailscaled is a plain userspace daemon
  # competing in system.slice. Give it priority over everything else.
  systemd.services.tailscaled.serviceConfig.CPUWeight = 500;

  # https://nixos.org/nixos/options.html
  system.stateVersion = "25.11";
}
