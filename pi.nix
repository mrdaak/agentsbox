# Pin pi-coding-agent to a newer release than the nixpkgs channel currently ships.

{ pkgs ? import <nixpkgs> { } }:

let
  version = "0.80.6";

  srcHash = "sha256-e/wcHruEcBAHDF5tKvwew7LXjVp0eraHh2k+QaL2sCA=";
  npmDepsHash = "sha256-xXEOR0epZcfbXayYGyJdBiFVliamBexqA+1Sd7wlGhU=";

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
