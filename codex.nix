# Pin the OpenAI Codex CLI to a specific release.

{ pkgs ? import <nixpkgs> { } }:

let
  version = "0.149.1";

  target = {
    aarch64-linux = "aarch64-unknown-linux-musl";
    x86_64-linux = "x86_64-unknown-linux-musl";
    aarch64-darwin = "aarch64-apple-darwin";
    x86_64-darwin = "x86_64-apple-darwin";
  }.${pkgs.stdenv.hostPlatform.system};

  sha256 = {
    aarch64-linux = "sha256-FN9oAuOalW3plOhEuQ1R2CVLzIBXtuZvDz47j34tpbA=";
    x86_64-linux = "sha256-4k+3hMfXEUDWevtiD1bpE3SWz39snhkhf6Nmbc8wYng=";
    aarch64-darwin = "sha256-7WD0dcbdpgRMLAD9fzMnPMPz+YkAzNEgS/3y/pNfNAU=";
    x86_64-darwin = "sha256-hf56g363Od1eHMWanJW3toIEjlqs3CYVBbrnaPsSiO8=";
  }.${pkgs.stdenv.hostPlatform.system};

  codeModeHost = pkgs.fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-code-mode-host-${target}.tar.gz";
    sha256 = {
      aarch64-linux = "sha256-li4CnfdytTy5d6AgTsQoTQxpMgeiWkkRBugpSq6N+gQ=";
      x86_64-linux = "sha256-YvosPl1LxYcgvXKy7iq4Y24aqp2CNt2uQaHM5ii1mus=";
      aarch64-darwin = "sha256-quHAyUWXAKLol62t1kc1EUCueTOtc72NOvZQXGmk8/0=";
      x86_64-darwin = "sha256-OiS8NC6g5gnnB/YhGYfUmcM8CaT3WJGpTdRr7498W74=";
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
