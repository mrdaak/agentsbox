# Pin the OpenAI Codex CLI to a specific release.

{ pkgs ? import <nixpkgs> { } }:

let
  version = "0.142.2";

  target = {
    aarch64-linux = "aarch64-unknown-linux-musl";
    x86_64-linux = "x86_64-unknown-linux-musl";
    aarch64-darwin = "aarch64-apple-darwin";
    x86_64-darwin = "x86_64-apple-darwin";
  }.${pkgs.stdenv.hostPlatform.system};

  sha256 = {
    aarch64-linux = "sha256-qIk3Lzn7PexuOfIjM5aFoBHTm7XEmoFHDUKbh23IZJM=";
    x86_64-linux = "sha256-EskAXId46fdiOxe3fzy/VugFmAmsaAJ7NWDBqBOapOI=";
    aarch64-darwin = "sha256-JkwVpjFGF22wMUxUcoQ3yXsRIbsmF8QmwGkl1itEVLM=";
    x86_64-darwin = "sha256-KU6BDnVKXGh7Cedr84YjjJ75/LWFI1S+wGPn+n1A1aU=";
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

    # bwrap rides with codex so it's present when codex is installed and absent
    # otherwise; only Linux needs it (codex's sandbox path is Linux-only).
    propagatedBuildInputs = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.bubblewrap ];

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
