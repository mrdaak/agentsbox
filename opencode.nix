# Pin opencode to a newer release than the nixpkgs channel currently ships.

{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

let
  version = "1.18.10";

  src = pkgs.fetchFromGitHub {
    owner = "anomalyco";
    repo = "opencode";
    tag = "v${version}";
    hash = "sha256-S90dh9+Xvpqva2L+gfIFJfSoL+mobXZZWMNkeegEYRE=";
  };

  nodeModulesHash = "sha256-/+sT9E8+SqUKVAzEYQoKoO0LEh73QoSbsY8nsoeIUPg=";

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
