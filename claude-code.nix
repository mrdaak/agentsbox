# Pin claude-code to a newer release than the nixpkgs channel currently ships.

{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

let
  version = "2.1.303";

  platformKey = {
    aarch64-linux = "linux-arm64";
    x86_64-linux = "linux-x64";
    aarch64-darwin = "darwin-arm64";
    x86_64-darwin = "darwin-x64";
  }.${pkgs.stdenv.hostPlatform.system};

  sha256 = {
    aarch64-linux = "sha256-SowNLgq08x0rPh3BNs7GzU7xDBw0iXyr3s6FcKSI0sQ=";
    x86_64-linux = "sha256-sAuSlbglFpl1mDyeHNPrLbvJyVgn+os3egvvC7i0cag=";
    aarch64-darwin = "sha256-SCqkkNweAyi+4QoWO+9/WcfHLhTedTVpa1vTrsAIn30=";
    x86_64-darwin = "sha256-7hSN8UJLVCKtbTSL4x8ITUZ7dM8f21ZOT57Hg/b74HU=";
  }.${pkgs.stdenv.hostPlatform.system};

  claude-zst = pkgs.fetchurl {
    url = "https://downloads.claude.ai/claude-code-releases/${version}/${platformKey}/claude.zst";
    inherit sha256;
  };

  claude-bin = pkgs.runCommand "claude" {
    nativeBuildInputs = [ pkgs.zstd ];
  } ''
    unzstd -q ${claude-zst} -o $out
    chmod 755 $out
  '';

  claude-code = pkgs.claude-code.overrideAttrs (old: {
    inherit version;
    src = claude-bin;
  });
in
{
  inherit claude-code;
}
