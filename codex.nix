# Pin the OpenAI Codex CLI to a specific release.
#
# Fetch OpenAI's official prebuilt release binary
# — the Linux assets are statically linked musl builds, so they run on NixOS
# as-is — and just install it. This is the codex analog of claude-code.nix:
# pin a version + per-platform hash, no source build, decoupled from nixpkgs lag.
#
# To upgrade: bump `version`, then set the matching `sha256`. Easiest way to get
# a hash is:
#   nix-prefetch-url https://github.com/openai/codex/releases/download/rust-v<version>/codex-<target>.tar.gz
#   nix hash convert --to sri --hash-algo sha256 <printed-base32>
# or build once with pkgs.lib.fakeHash and let Nix print the real hash.

{ pkgs ? import <nixpkgs> { } }:

let
  version = "0.138.0";

  target = {
    aarch64-linux = "aarch64-unknown-linux-musl";
    x86_64-linux = "x86_64-unknown-linux-musl";
    aarch64-darwin = "aarch64-apple-darwin";
    x86_64-darwin = "x86_64-apple-darwin";
  }.${pkgs.stdenv.hostPlatform.system};

  sha256 = {
    aarch64-linux = "sha256-uOkG7fvBquAIucWPdmJmaiyRpYfCy8kRlqD2L8UQI1w=";
    # Fill these in the first time you build on the platform:
    x86_64-linux = pkgs.lib.fakeHash;
    aarch64-darwin = pkgs.lib.fakeHash;
    x86_64-darwin = pkgs.lib.fakeHash;
  }.${pkgs.stdenv.hostPlatform.system};

  codex = pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "codex";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-${target}.tar.gz";
      inherit sha256;
    };

    # The tarball is a single binary file, not a directory.
    sourceRoot = ".";

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 codex-${target} $out/bin/codex
      runHook postInstall
    '';

    meta = {
      description = "OpenAI Codex CLI (pinned prebuilt release binary)";
      mainProgram = "codex";
      platforms = builtins.attrNames {
        aarch64-linux = null;
        x86_64-linux = null;
        aarch64-darwin = null;
        x86_64-darwin = null;
      };
    };
  });
in
{
  inherit codex;
}
