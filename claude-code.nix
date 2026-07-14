# Pin claude-code to a newer release than the nixpkgs channel currently ships.

{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

let
  version = "2.1.209";

  platformKey = {
    aarch64-linux = "linux-arm64";
    x86_64-linux = "linux-x64";
    aarch64-darwin = "darwin-arm64";
    x86_64-darwin = "darwin-x64";
  }.${pkgs.stdenv.hostPlatform.system};

  sha256 = {
    aarch64-linux = "sha256-J4y2jvchfPzFyUnSVzu45ZqLEwX3Zon7qI63IrDZ4vA=";
    x86_64-linux = "sha256-uIL0uLJ3cviXVA31DyQAAgb0OpQm6PfRm9BllZtp6d0=";
    aarch64-darwin = "sha256-WdLef0nbL3XVwzu7Rqa48oitJNQLYeMGAqUCu33cOAw=";
    x86_64-darwin = "sha256-TMP0S5BdRb0nptuTBuxt6Siup1hTcgUymFGuR48vosY=";
  }.${pkgs.stdenv.hostPlatform.system};

  claude-code = pkgs.claude-code.overrideAttrs (old: {
    inherit version;
    src = pkgs.fetchurl {
      url = "https://downloads.claude.ai/claude-code-releases/${version}/${platformKey}/claude";
      inherit sha256;
    };
  });
in
{
  inherit claude-code;
}
