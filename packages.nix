# Single source of truth for every tool installed into the image.
#
# Install with one profile generation:
#   nix profile add --priority 4 -f ./packages.nix
#
# installedAgents is supplied at image-build time via the AGENTSBOX_INSTALLED_AGENTS
# build-arg (see Containerfile / make.nu). It is a whitespace/newline-separated
# list drawn from {claude, codex, pi, opencode}; empty/unset => all four
# (backward-compatible). Validation lives in make.nu; this file trusts its input.
{ pkgs ? import (builtins.fetchTarball {
url = "https://github.com/NixOS/nixpkgs/archive/nixos-26.05.tar.gz";
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

  # The four agents. opencode is a nixpkgs entry (not a pinned file), gated the
  # same way as the three pinned derivations so the selection is uniform.
  selectedAgents =
    (pkgs.lib.optionals (has "claude") [ claude-code ])
    ++ (pkgs.lib.optionals (has "codex") [ codex ])
    ++ (pkgs.lib.optionals (has "pi") [ pi-coding-agent ])
    ++ (pkgs.lib.optionals (has "opencode") [ pkgs.opencode ]);
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
