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

            opencode() {
              make -f $OPENCODE_TOOLS_DIR/Makefile run WORKDIR=$PWD ARGS="$*"
            }

            opencode-update() {
              make -f $OPENCODE_TOOLS_DIR/Makefile update
            }

            echo ""
            echo "Available commands:"
            echo "  opencode              - Run OpenCode in current directory (args optional)"
            echo "  opencode-update       - Pull latest base image and rebuild"
            echo ""
            echo "Manual make usage:"
            echo "  make run WORKDIR=~/src/my-project"
          '';
        };
      }
    );
}
