# Pin pi-coding-agent to a newer release than the nixpkgs channel currently ships.
#
# Upstream's derivation builds from source using buildNpmPackage. We reuse all of
# that via overrideAttrs and only swap the version, source hash, and npm
# dependencies.
#
# To upgrade: bump `version`, then set the matching `srcHash` and `npmDepsHash`.
# Easiest way to get the hashes is to build once with `pkgs.lib.fakeHash` and
# let Nix print the real ones:
#
#   nix build --impure --expr 'with import ./pi.nix { }; pi-coding-agent.outPath'
#
# Or use nix-prefetch-from-github / prefetch-npm-deps.

{ pkgs ? import <nixpkgs> { } }:

let
  version = "0.79.9";

  srcHash = "sha256-+h1D51JM4F2iHCzTA57A5/uAzHQBKSlz/7x3/PtQhec=";
  npmDepsHash = "sha256-uej0uXVbihmxpuvviCK/5JFSEqDamIW5ETOL/ZKW45g=";

  src = pkgs.fetchFromGitHub {
    owner = "earendil-works";
    repo = "pi";
    tag = "v${version}";
    hash = srcHash;
  };

  npmDeps = pkgs.fetchNpmDeps {
    inherit src;
    name = "pi-coding-agent-${version}-npm-deps";
    hash = npmDepsHash;
    fetcherVersion = 1;
  };

  pi-coding-agent = pkgs.pi-coding-agent.overrideAttrs (old: {
    inherit version src;
    npmDeps = npmDeps;
  });
in
{
  inherit pi-coding-agent;
}
