# Pin claude-code to a newer release than the nixpkgs channel currently ships.
#
# Upstream's derivation just downloads a prebuilt native binary and runs it
# through autoPatchelfHook + a wrapper (ripgrep/procps/bubblewrap/socat). We
# reuse all of that via overrideAttrs and only swap the version + source.
#
# To upgrade: bump `version`, then set the matching `sha256`. Easiest way to
# get the hash is to build once with `pkgs.lib.fakeHash` and let Nix print the
# real one, or run `nix hash file <path-to-the-downloaded-claude-binary>`.

{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

let
  version = "2.1.170";

  platformKey = {
    aarch64-linux = "linux-arm64";
    x86_64-linux = "linux-x64";
    aarch64-darwin = "darwin-arm64";
    x86_64-darwin = "darwin-x64";
  }.${pkgs.stdenv.hostPlatform.system};

  sha256 = {
    aarch64-linux = "sha256-G7nQMkQKdVMvfdTK+8aH8iCq8Wxj66F+GS377C8EvSU=";
    # Fill these in the first time you build on the platform:
    x86_64-linux = pkgs.lib.fakeHash;
    aarch64-darwin = pkgs.lib.fakeHash;
    x86_64-darwin = pkgs.lib.fakeHash;
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
