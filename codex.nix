# Pin the OpenAI Codex CLI to a specific release.

{ pkgs ? import <nixpkgs> { } }:

let
  version = "0.163.0";

  target = {
    aarch64-linux = "aarch64-unknown-linux-musl";
    x86_64-linux = "x86_64-unknown-linux-musl";
    aarch64-darwin = "aarch64-apple-darwin";
    x86_64-darwin = "x86_64-apple-darwin";
  }.${pkgs.stdenv.hostPlatform.system};

  sha256 = {
    aarch64-linux = "sha256-pyYeZfSpbY9MploGnGzy3Cwz3vw0HkgHis79qUYf/+Q=";
    x86_64-linux = "sha256-vrM56OzZugV6a7Lcga2MpHSBLt+/D8UFbKgYeXZI3eQ=";
    aarch64-darwin = "sha256-YcTZqSUhvbQrDB2fh8Zz9tpiigbeWUXL3ZoAEGMvbRA=";
    x86_64-darwin = "sha256-Vioa6g5Whig6RnaH0miuM3BfAv1NQPG8QRCkFcXBx7E=";
  }.${pkgs.stdenv.hostPlatform.system};

  codeModeHost = pkgs.fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-code-mode-host-${target}.tar.gz";
    sha256 = {
      aarch64-linux = "sha256-KENWrvsZfwC3a5Eu/f266Mzz6h+JuXbd4GS3zLQyFO8=";
      x86_64-linux = "sha256-MUJjEoumWS5+gHwmXe6vkoppK3Lcv+teCyDJQjtwNSk=";
      aarch64-darwin = "sha256-Lij0mkdnqXWGhDySaSuWSBvnTYNxmbSQOPcxzsiOmUE=";
      x86_64-darwin = "sha256-UhHG7VBiyEuleW5VWQPCKm44/Mz2/hHuEdfhtWh84f0=";
    }.${pkgs.stdenv.hostPlatform.system};
  };

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
      tar -xOf ${codeModeHost} codex-code-mode-host-${target} > $out/bin/codex-code-mode-host
      chmod 755 $out/bin/codex-code-mode-host
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
