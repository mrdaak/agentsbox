# Single source of truth for every tool installed into the image.
#
# Install with one profile generation:
#   nix profile add --priority 4 -f ./packages.nix
{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

let
  claude-code = (import ./claude-code.nix { inherit pkgs; }).claude-code;
  codex = (import ./codex.nix { inherit pkgs; }).codex;
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
    opencode
    unzip
    gnused
    socat
  ]) ++ [
    claude-code
    codex
  ];

  # Tolerate file overlap between packages within this set (e.g. multiple
  # providing the same man page). Collisions against the base image's existing
  # profile entries are handled separately by `--priority` at install time.
  ignoreCollisions = true;
}
