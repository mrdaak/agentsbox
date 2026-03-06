{
  description = "AI agents shell";

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
            export AGENTS_TOOLS_DIR=$(pwd)
            export PATH="$AGENTS_TOOLS_DIR/bin:$PATH"

            echo ""
            echo "Available commands:"
            echo "  agents                - Select an agent to run within the scope of current directory"
            echo "  agents-update         - Pull latest base image and rebuild"
            echo ""
            echo "Manual make usage:"
            echo "  make run WORKDIR=~/src/my-project"
          '';
        };
      }
    );
}
