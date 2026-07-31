# Pin the OpenAI Codex CLI to a specific release.

{ pkgs ? import <nixpkgs> { } }:

let
  version = "0.146.0";

  target = {
    aarch64-linux = "aarch64-unknown-linux-musl";
    x86_64-linux = "x86_64-unknown-linux-musl";
    aarch64-darwin = "aarch64-apple-darwin";
    x86_64-darwin = "x86_64-apple-darwin";
  }.${pkgs.stdenv.hostPlatform.system};

  sha256 = {
    aarch64-linux = "sha256-l1uskVYqvu3rj3ljbVGoZkmzHzSp3mo7ywWVZbbPH4c=";
    x86_64-linux = "sha256-W6O5QFVDlTCB9mHQhU0mb3biq75R1BNJNVo23nZzd2o=";
    aarch64-darwin = "sha256-J1ATLTAOZPHb/7lePZE/2cnceBK8jhvOXGE1cki3kp4=";
    x86_64-darwin = "sha256-cQ1yew+itKshiesb3Fq0AXfBaClq8mSRPrerPOhI0Es=";
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
