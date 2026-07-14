# Pin opencode to a newer release than the nixpkgs channel currently ships.

{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

let
  version = "1.17.20";

  src = pkgs.fetchFromGitHub {
    owner = "anomalyco";
    repo = "opencode";
    tag = "v${version}";
    hash = "sha256-gHfkwCi6Kjn5ppsuyhyM2vyaLmAoNdWth6Xz4LaV7Hk=";
  };

  nodeModulesHash = "sha256-3NAzmlzVBcLSRXxpNOyW5DKfD1i2HReST2jlKgrtOKc=";

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
