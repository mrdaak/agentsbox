# Pin claude-code to a newer release than the nixpkgs channel currently ships.

{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

let
  version = "2.1.281";

  platformKey = {
    aarch64-linux = "linux-arm64";
    x86_64-linux = "linux-x64";
    aarch64-darwin = "darwin-arm64";
    x86_64-darwin = "darwin-x64";
  }.${pkgs.stdenv.hostPlatform.system};

  sha256 = {
    aarch64-linux = "sha256-dYO2VYVWHHFOGMrKReDg+5vbptftbuXVFxg01cZXrqY=";
    x86_64-linux = "sha256-T/ufa6raTYi72MWGdz79BgXFJMejHMODPu2iKXF6eyU=";
    aarch64-darwin = "sha256-BWZipOOlyjd3BzClk0XRtXlu9lREwyuX0jZlGraPP6E=";
    x86_64-darwin = "sha256-CF3ZlSmZx0LPJi0P7VccO810nVEn633UVbxb4JSMe50=";
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
