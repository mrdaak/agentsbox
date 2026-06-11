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

        agentsbox = pkgs.stdenv.mkDerivation {
          pname = "agentsbox";
          version = "0.1.0";
          src = ./.;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          dontConfigure = true;
          dontBuild = true;

          installPhase = ''
            runHook preInstall

            mkdir -p $out/share/agents $out/bin
            cp -r Makefile Containerfile bin zellij-config.kdl $out/share/agents/
            chmod +x $out/share/agents/bin/*

            makeWrapper $out/share/agents/bin/agentsbox $out/bin/agentsbox \
              --set AGENTS_TOOLS_DIR $out/share/agents \
              --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps}

            runHook postInstall
          '';

          meta.mainProgram = "agentsbox";
        };
      in
      {
        packages = {
          default = agentsbox;
          agentsbox = agentsbox;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [ pkgs.gnumake pkgs.podman pkgs.zellij pkgs.nushell ];

          shellHook = ''
            export AGENTS_TOOLS_DIR=$(pwd)
            export PATH="$AGENTS_TOOLS_DIR/bin:$PATH"

            echo ""
            echo "Available commands:"
            echo "  agentsbox enter        - Enter an agent shell in the current directory"
            echo "  agentsbox list         - List running agent containers"
            echo "  agentsbox load-secret  - Load a file as a podman secret for a project"
            echo "  agentsbox update       - Pull latest base image and rebuild"
            echo "  agentsbox doctor       - Check host environment for required tooling"
            echo ""
            echo "Manual make usage:"
            echo "  make run WORKDIR=~/src/my-project"
          '';
        };
      }
    );
}
