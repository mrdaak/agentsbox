# Pin pi-coding-agent to a newer release than the nixpkgs channel currently ships.

{ pkgs ? import <nixpkgs> { } }:

let
  version = "0.87.1";

  srcHash = "sha256-GUhlq6t+l6iiViOZ0bkV28v3ZDqcLvEwpZpYZ5JAyDk=";
  npmDepsHash = "sha256-JBIYoP2vvRNz1HONNvDJ1U3c+nmCJ7/VgNthRTkrkIA=";

  # Mirrors the upstream package.nix; bump this hash alongside version.
  modelData = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${version}.tgz";
    hash = "sha256-NbRDLyfMJmX4a+67mvajmxJRlwiDwwRL2L5PToxzHKA=";
  };

  src = pkgs.fetchFromGitHub {
    owner = "earendil-works";
    repo = "pi";
    tag = "v${version}";
    hash = srcHash;
  };

  npmDeps = pkgs.fetchNpmDeps {
    inherit src;
    name = "pi-coding-agent-${version}-npm-deps";
    hash = npmDepsHash;
    fetcherVersion = 1;
  };

  pi-coding-agent = pkgs.pi-coding-agent.overrideAttrs (_old: {
    inherit version src npmDeps modelData;

    preConfigure = ''
      mkdir -p packages/ai/src/providers/data
      tar --extract --gzip --file=${modelData} \
        --directory=packages/ai/src/providers/data \
        --strip-components=4 \
        package/dist/providers/data
    '';

    buildPhase = ''
      runHook preBuild

      npx tsgo -p packages/chord/tsconfig.build.json
      npx tsgo -p packages/tui/tsconfig.build.json
      npx tsgo -p packages/telemetry/tsconfig.build.json
      npx tsgo -p packages/ai/tsconfig.build.json
      npx tsgo -p packages/agent/tsconfig.build.json
      npx tsgo -p packages/protocol/tsconfig.build.json
      npx tsgo -p packages/client/tsconfig.build.json
      npx tsgo -p packages/server/tsconfig.build.json
      npm run build --workspace=packages/coding-agent

      runHook postBuild
    '';

    # Skip native module rebuild for unneeded workspaces (e.g. canvas from
    # web-ui) during the inherited base installPhase's `npm rebuild`.
    npmRebuildFlags = [ "--ignore-scripts" ];

    dontNpmPrune = true;

    preInstall = ''
      npm prune --omit=dev --no-save
    '';

    # npm workspace symlinks in the output point into packages/ which doesn't
    # exist there. Replace the runtime workspace deps with built copies and
    # delete the rest. The base 0.75.4 postInstall only handled ai/agent-core/
    # tui; 0.87.x also needs chord/client/protocol/telemetry.
    postInstall = ''
      local nm="$out/lib/node_modules/pi-monorepo/node_modules"

      for ws in @earendil-works/chord:packages/chord \
                @earendil-works/pi-ai:packages/ai \
                @earendil-works/pi-agent-core:packages/agent \
                @earendil-works/pi-client:packages/client \
                @earendil-works/pi-protocol:packages/protocol \
                @earendil-works/pi-telemetry:packages/telemetry \
                @earendil-works/pi-tui:packages/tui; do
        IFS=: read -r pkg src <<< "$ws"
        rm "$nm/$pkg"
        cp -r "$src" "$nm/$pkg"
      done

      find "$nm" -type l -lname '*/packages/*' -delete
      find "$nm/.bin" -xtype l -delete
    '' + pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
      rm -rf \
        "$nm/@anthropic-ai/sandbox-runtime/dist/vendor/seccomp" \
        "$nm/@anthropic-ai/sandbox-runtime/vendor/seccomp"
    '';

    # Re-include the base's ripgrep/fd PATH wrap (overrideAttrs replaces
    # postFixup wholesale) and add the 0.87.x env defaults.
    postFixup = ''
      wrapProgram $out/bin/pi --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.ripgrep pkgs.fd ]} \
        --set-default PI_SKIP_VERSION_CHECK 1 \
        --set-default PI_TELEMETRY 0
    '';
  });
in
{
  inherit pi-coding-agent;
}
