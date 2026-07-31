# Pin claude-code to a newer release than the nixpkgs channel currently ships.

{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

let
  version = "2.1.220";

  platformKey = {
    aarch64-linux = "linux-arm64";
    x86_64-linux = "linux-x64";
    aarch64-darwin = "darwin-arm64";
    x86_64-darwin = "darwin-x64";
  }.${pkgs.stdenv.hostPlatform.system};

  sha256 = {
    aarch64-linux = "sha256-FZ5KUdeW878UZ3V3EA9++4RWEbHOrwwwy9jUZQ2UIYU=";
    x86_64-linux = "sha256-Z09h8g/zBvMQDPkgDkw2xLcCeLW+8ohFSYGblCqJyGM=";
    aarch64-darwin = "sha256-it3IV/P+ZNWgNor57lAyG1CvtKaRi6PvAYq4T1274IE=";
    x86_64-darwin = "sha256-3Ke+CqfT2SSDbUQODG2OPUfvPI5h+lgJtUuQFxcM4vM=";
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
