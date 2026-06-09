{
  description = "AI agents shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        runtimeDeps = [
          pkgs.gnumake
          pkgs.podman
          pkgs.nushell
          pkgs.jq
          pkgs.perl
          pkgs.coreutils
        ];

        agents = pkgs.stdenv.mkDerivation {
          pname = "agents";
          version = "0.1.0";
          src = ./.;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          dontConfigure = true;
          dontBuild = true;

          installPhase = ''
            runHook preInstall

            mkdir -p $out/share/agents $out/bin
            cp -r Makefile Containerfile bin $out/share/agents/
            chmod +x $out/share/agents/bin/*

            makeWrapper $out/share/agents/bin/agents $out/bin/agents \
              --set AGENTS_TOOLS_DIR $out/share/agents \
              --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps}

            runHook postInstall
          '';

          meta.mainProgram = "agents";
        };
      in
      {
        packages = {
          default = agents;
          agents = agents;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [ pkgs.gnumake pkgs.podman pkgs.zellij pkgs.nushell ];

          shellHook = ''
            export AGENTS_TOOLS_DIR=$(pwd)
            export PATH="$AGENTS_TOOLS_DIR/bin:$PATH"

            echo ""
            echo "Available commands:"
            echo "  agents enter        - Enter an agent shell in the current directory"
            echo "  agents list         - List running agent containers"
            echo "  agents load-secret  - Load a file as a podman secret for a project"
            echo "  agents update       - Pull latest base image and rebuild"
            echo "  agents doctor       - Check host environment for required tooling"
            echo ""
            echo "Manual make usage:"
            echo "  make run WORKDIR=~/src/my-project"
          '';
        };
      }
    );
}
