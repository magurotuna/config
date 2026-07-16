# hermes-agent (NousResearch) Discord daemon, egress-confined via clawpatrol.
#
# The hermes install itself is imperative (upstream install.sh into
# /home/hermes, self-updating). NixOS declares: the dedicated user,
# system-wide clawpatrol, and the systemd unit that wraps the daemon in
# `clawpatrol run` so every outbound request traverses the clawpatrol
# gateway (per-process netns + credential injection).
#
# Bootstrap (one-time, as the hermes user via `sudo -iu hermes`):
#   1. curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
#   2. clawpatrol join against the gateway (approve in the dashboard;
#      NEVER run join via sudo/root)
#   3. write ~/.hermes/.env (placeholder DISCORD_BOT_TOKEN only — the real
#      token lives solely in the gateway; DISCORD_ALLOWED_USERS required)
# Until all three exist the unit skips cleanly via ConditionPathExists.
#
# Operational rule: manage with systemctl only. `hermes gateway start/stop`
# would install a competing user-scope unit — never use those here.
{ config, pkgs, lib, ... }:

{
  # The clawpatrol overlay is only wired into home-manager's mkPkgs today;
  # the NixOS eval needs it too for environment.systemPackages.
  nixpkgs.overlays = [ (import ../overlays/clawpatrol.nix) ];
  environment.systemPackages = [ pkgs.clawpatrol ];

  users.groups.hermes = { };
  users.users.hermes = {
    isNormalUser = true;
    group = "hermes";
    home = "/home/hermes";
    description = "hermes-agent service user (all egress via clawpatrol)";
    shell = pkgs.bash;
    # deliberately NO extraGroups: no wheel, docker, networkmanager, ...
  };

  systemd.services.hermes-gateway = {
    description = "hermes-agent messaging gateway (Discord), via clawpatrol run";
    after = [ "network-online.target" "tailscaled.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    # Enabled from day one, but skips cleanly (no failure, no crash-loop)
    # until the human bootstrap (install.sh + clawpatrol join + .env) is done.
    unitConfig = {
      ConditionPathExists = [
        "/home/hermes/.clawpatrol/api-token"
        "/home/hermes/.hermes/.env"
        "/home/hermes/.local/bin/hermes"
      ];
      StartLimitIntervalSec = 0;
    };

    environment = {
      HOME = "/home/hermes";
      HERMES_HOME = "/home/hermes/.hermes";
      # Include ~/.nix-profile/bin so tools hermes installs imperatively with
      # `nix profile install` (psql, kubectl, clickhouse, aws, …) are visible to
      # the daemon without a nixos-rebuild. This keeps package additions a
      # sudo-free, no-rebuild operation the agent can do itself.
      PATH = lib.mkForce "/home/hermes/.local/bin:/home/hermes/.nix-profile/bin:/run/current-system/sw/bin";
    };

    serviceConfig = {
      Type = "simple";
      User = "hermes";
      Group = "hermes";
      WorkingDirectory = "/home/hermes";
      # clawpatrol run creates the netns/TUN first, then the agent is
      # confined with no_new_privs (the reverse order would break
      # namespace setup).
      ExecStart = lib.concatStringsSep " " [
        "/run/current-system/sw/bin/clawpatrol"
        "run"
        "--"
        "${pkgs.util-linux}/bin/setpriv"
        "--no-new-privs"
        "--"
        "/home/hermes/.local/bin/hermes"
        "gateway"
        "run"
      ];
      Restart = "always";
      RestartSec = 5;
      # hermes exits 75 to request a respawn (self-update / /restart).
      RestartForceExitStatus = 75;
      KillMode = "mixed";
      KillSignal = "SIGTERM";
      TimeoutStopSec = 120; # hermes drains sessions before SIGKILL
      ExecReload = "${pkgs.coreutils}/bin/kill -USR1 $MAINPID";

      # DO NOT ADD (each breaks clawpatrol run or the join state):
      #   NoNewPrivileges=true   -> must come AFTER clawpatrol run (setpriv above)
      #   RestrictNamespaces     -> blocks the private user+net namespace
      #   PrivateDevices=true    -> hides /dev/net/tun
      #   PrivateNetwork=true    -> kills the tailnet path to the gateway
      #   ProtectHome=true       -> hides ~/.clawpatrol, ~/.hermes, the venv
    };
  };
}
