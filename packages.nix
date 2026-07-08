# Single source of truth for every tool installed into the image.
#
# Install with one profile generation:
#   nix profile add --priority 4 -f ./packages.nix
#
# installedAgents is supplied at image-build time via the AGENTSBOX_INSTALLED_AGENTS
# build-arg (see Containerfile / make.nu). It is a whitespace/newline-separated
# list drawn from {claude, codex, pi, opencode}; empty/unset => all four
# (backward-compatible). Validation lives in make.nu; this file trusts its input.
#
# nixpkgs is pinned to a specific commit (not the moving nixos-26.05 branch) so
# the container build layer is reproducible and its podman cache key stays stable
{ pkgs ? import (builtins.fetchTarball {
  url = "https://github.com/NixOS/nixpkgs/archive/0ad6f47ea4fe188f4bc8f0380f93ae8523337c6c.tar.gz";
  sha256 = "sha256-0xIy4dVLqq47rA+mRy0hXDfjhQd4E5PoIns/RmB7nR4=";
  }) { config.allowUnfree = true; }
}:

let
  raw = builtins.getEnv "AGENTSBOX_INSTALLED_AGENTS";
  parts = builtins.filter builtins.isString (builtins.split "[ \n\t]+" raw);
  parsed = builtins.filter (s: s != "") parts;
  installedAgents =
    if parsed == [] then [ "claude" "codex" "pi" "opencode" ] else parsed;

  has = name: builtins.elem name installedAgents;

  claude-code = (import ./claude-code.nix { inherit pkgs; }).claude-code;
  codex = (import ./codex.nix { inherit pkgs; }).codex;
  pi-coding-agent = (import ./pi.nix { inherit pkgs; }).pi-coding-agent;
  opencode = (import ./opencode.nix { inherit pkgs; }).opencode;

  # The four agents, each pinned to a specific release via its own .nix file.
  selectedAgents =
    (pkgs.lib.optionals (has "claude") [ claude-code ])
    ++ (pkgs.lib.optionals (has "codex") [ codex ])
    ++ (pkgs.lib.optionals (has "pi") [ pi-coding-agent ])
    ++ (pkgs.lib.optionals (has "opencode") [ opencode ]);
in
pkgs.buildEnv {
  name = "agents-tools";

  paths = (with pkgs; [
    gitMinimal
    jq
    ripgrep
    fd
    gnumake
    zellij
    cacert
    less
    ncurses
    tree
    bash
    curl
    gnutar
    nodejs
    unzip
    gnused
    socat
  ]) ++ selectedAgents;

  # Tolerate file overlap between packages within this set (e.g. multiple
  # providing the same man page). Collisions against the base image's existing
  # profile entries are handled separately by `--priority` at install time.
  ignoreCollisions = true;
}
