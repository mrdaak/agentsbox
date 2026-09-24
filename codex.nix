# Pin the OpenAI Codex CLI to a specific release.

{ pkgs ? import <nixpkgs> { } }:

let
  version = "0.156.1";

  target = {
    aarch64-linux = "aarch64-unknown-linux-musl";
    x86_64-linux = "x86_64-unknown-linux-musl";
    aarch64-darwin = "aarch64-apple-darwin";
    x86_64-darwin = "x86_64-apple-darwin";
  }.${pkgs.stdenv.hostPlatform.system};

  sha256 = {
    aarch64-linux = "sha256-VY4SqqbayzNexHJAv5ch24pUdGgG1k8BGFpAP0T3m3I=";
    x86_64-linux = "sha256-r/RlOag6/4bjxixZK84sUNlTkfnfKJr68DpQwB0UUz0=";
    aarch64-darwin = "sha256-K9ZK8U3t1HeV8va/1dElz3kZmswse6IiFE4IEnERpco=";
    x86_64-darwin = "sha256-VeNFht7lNyDdlEUQImMv/8njtVskcVrN2UU/01ZqVN8=";
  }.${pkgs.stdenv.hostPlatform.system};

  codeModeHost = pkgs.fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-code-mode-host-${target}.tar.gz";
    sha256 = {
      aarch64-linux = "sha256-QBmBOLA3mP+owNpMgnqMpYlndOoQS3EQwqLAx1YMvpQ=";
      x86_64-linux = "sha256-qSnaqfagvdwAwMnmQC3xF7ElrNlvnVVPbJnDLH5mxgg=";
      aarch64-darwin = "sha256-JiXQI+K24D0rzEN6Pg4IMcJdPHItKFRjio50kh/3m9k=";
      x86_64-darwin = "sha256-/JaNnnIS1/ux4VRtKDbzsHxfOIEJwFuEKMHz8wkdcgk=";
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
