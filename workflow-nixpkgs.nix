# Provide the pinned nixpkgs package set for workflow images.
import (builtins.fetchTarball {
  url = "https://github.com/NixOS/nixpkgs/archive/f20cd90e28fe0403873f473b29e42662cd86e8c4.tar.gz";
  sha256 = "sha256-EjZqHKObBfIOeHZnMRVV87HB3pPq/WBkmRJWyFxmZu8=";
}) { config.allowUnfree = true; }
