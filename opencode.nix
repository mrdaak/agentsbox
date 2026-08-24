# Pin opencode to a newer release than the nixpkgs channel currently ships.

{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

let
  version = "1.18.21";

  src = pkgs.fetchFromGitHub {
    owner = "anomalyco";
    repo = "opencode";
    tag = "v${version}";
    hash = "sha256-WKG/lts+wzDjYJ5pOZ0X4Kb0rJ1TzYQzQgjyQBY+bxs=";
  };

  nodeModulesHash = "sha256-dGASaxZnxzJZY1PuDeqQCnYgMm2gEf5HZQsWOnt2JaU=";

  opencode = pkgs.opencode.overrideAttrs (old: {
    inherit version src;

    node_modules = old.node_modules.overrideAttrs (nmold: {
      inherit version src;
      outputHash = nodeModulesHash;
    });
  });
in
{
  inherit opencode;
}
