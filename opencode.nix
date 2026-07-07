# Pin opencode to a newer release than the nixpkgs channel currently ships.

{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

let
  version = "1.17.12";

  src = pkgs.fetchFromGitHub {
    owner = "anomalyco";
    repo = "opencode";
    tag = "v${version}";
    hash = "sha256-eM+K/JrSjM5OtDLvPAXLQQx45K15rCxkac+HA8nq5gw=";
  };

  nodeModulesHash = "sha256-bHEJKhmaqPO4+H3x7lNBxU/9dMd354bJ1hg7wakHXJQ=";

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
