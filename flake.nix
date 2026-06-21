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
          pkgs.nushell
          pkgs.jq
          pkgs.coreutils
        ];

        agentsbox = pkgs.stdenv.mkDerivation {
          pname = "agentsbox";
          version = "0.1.10";
          src = ./.;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          dontConfigure = true;
          dontBuild = true;

          # Do NOT rewrite shebangs. patchShebangs would turn the scripts'
          # `#!/usr/bin/env bash` (and `…env node`) into hardcoded build-time
          # /nix/store paths. bin/shell-entrypoint, listen-message and
          # send-message are COPY'd into the container image, whose nix store
          # has DIFFERENT store paths — so a patched shebang points at a bash
          # that doesn't exist in the container and the entrypoint fails with
          # `exec … No such file or directory`.
          dontPatchShebangs = true;

          installPhase = ''
            runHook preInstall

            mkdir -p $out/share/agents $out/bin
            cp -r make.nu Containerfile packages.nix claude-code.nix codex.nix pi.nix bin skills zellij-config.kdl $out/share/agents/
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
          buildInputs = [ pkgs.podman pkgs.nushell ];

          shellHook = ''
            export AGENTS_TOOLS_DIR=$(pwd)
            export PATH="$AGENTS_TOOLS_DIR/bin:$PATH"
          '';
        };
      }
    );
}
