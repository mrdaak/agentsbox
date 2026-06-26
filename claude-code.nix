# Pin claude-code to a newer release than the nixpkgs channel currently ships.

{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

let
  version = "2.1.193";

  platformKey = {
    aarch64-linux = "linux-arm64";
    x86_64-linux = "linux-x64";
    aarch64-darwin = "darwin-arm64";
    x86_64-darwin = "darwin-x64";
  }.${pkgs.stdenv.hostPlatform.system};

  sha256 = {
    aarch64-linux = "sha256-OUVM5i55XutIcagfZFPNqW6Sbi25pN1B0OwbYLAVNEg=";
    x86_64-linux = "sha256-yfBNkp8YvZoQHziX8n3k4eDxXr6EANSq8CmD1z3Wax0=";
    aarch64-darwin = "sha256-91E6MDha2QGcI3Im/W7EZQizBi6+/Kiu2+OX0RGoGP8=";
    x86_64-darwin = "sha256-y6XDvcqKtfjnWQQGcC1Bj2EU2bOfSPFodmgOiBq/Hug=";
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
