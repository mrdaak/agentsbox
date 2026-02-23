{
  description = "OpenCode development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = [ pkgs.gnumake pkgs.podman ];

          shellHook = ''
            export OPENCODE_TOOLS_DIR=$(pwd)
            alias opencode='make -f $OPENCODE_TOOLS_DIR/Makefile run WORKDIR=$PWD'
            alias opencode-update='podman pull ghcr.io/anomalyco/opencode:latest'

            echo ""
            echo "Available aliases:"
            echo "  opencode        - Run OpenCode in current directory"
            echo "  opencode-update - Pull latest base image"
            echo ""
            echo "Usage: cd ~/src/my-project && opencode"
          '';
        };
      }
    );
}
