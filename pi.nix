# Pin pi-coding-agent to a newer release than the nixpkgs channel currently ships.

{ pkgs ? import <nixpkgs> { } }:

let
  version = "1.3.0";

  src = pkgs.fetchFromGitHub {
    owner = "earendil-works";
    repo = "pi";
    tag = "v${version}";
    hash = "sha256-AsutbwnjiwwLkB5tqLW+1GdGZyLmXsU0W+SNdNhJu7U=";
  };
in
{
  # Build with the release's own derivation so the package layout stays in sync
  # with upstream; `source` must point at the fetched repository root.
  pi-coding-agent =
    (pkgs.callPackage (src + "/nix/package.nix") { source = src; }).overrideAttrs (old: {
      # Upstream does not disable the version check or telemetry; keep the
      # offline defaults this pin has always provided.
      postFixup = (old.postFixup or "") + ''
        wrapProgram $out/bin/pi \
          --set-default PI_SKIP_VERSION_CHECK 1 \
          --set-default PI_TELEMETRY 0
      '';
    });
}
