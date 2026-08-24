# Pin claude-code to a newer release than the nixpkgs channel currently ships.

{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

let
  version = "2.1.241";

  platformKey = {
    aarch64-linux = "linux-arm64";
    x86_64-linux = "linux-x64";
    aarch64-darwin = "darwin-arm64";
    x86_64-darwin = "darwin-x64";
  }.${pkgs.stdenv.hostPlatform.system};

  sha256 = {
    aarch64-linux = "sha256-LbDLiT6+2O+K7kZlbaRbxoAfolhik9rmSr+jreiUov4=";
    x86_64-linux = "sha256-B3G9hmz/grdlgfwEmfZSnho2hFB48UT4yB3Ms7xwN7g=";
    aarch64-darwin = "sha256-FJXrfELTtEUfXxzTi21JjSKko4yAK8K+XBzxeV5kgg0=";
    x86_64-darwin = "sha256-zwG4ys5mSF71tHbxTZb2mvYRlKOMPfhBKoDrjxMWwQ0=";
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
