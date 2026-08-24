# Pin pi-coding-agent to a newer release than the nixpkgs channel currently ships.

{ pkgs ? import <nixpkgs> { } }:

let
  version = "0.84.3";

  srcHash = "sha256-fC9pKgP2qD61ae5d7iOqP8anl88J1N1Bq8X8+aAjA2A=";
  npmDepsHash = "sha256-cDx28+c4bwtQpiy5+BCvZhZezoZb4WRqfZj2eoEeMbw=";

  # Mirrors the upstream package.nix; bump this hash alongside version.
  modelData = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${version}.tgz";
    hash = "sha256-nECvL0OVD46U57vNDBs1SPAAly2gDE+5wNBSnU19VDE=";
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

  # Mirrors the upstream package.nix for the 0.84.x line. overrideAttrs swaps
  # version/src/hashes but NOT the build-phase attrs, so the buildPhase /
  # postInstall / postFixup must be mirrored too: 0.84.x added a `telemetry`
  # workspace that must build before `ai`, plus `protocol`/`client` before
  # `coding-agent`, a controlled `npm prune` (dontNpmPrune + preInstall), and
  # two extra runtime workspace deps (client/protocol/telemetry) in postInstall.
  pi-coding-agent = pkgs.pi-coding-agent.overrideAttrs (_old: {
    inherit version src npmDeps modelData;

    preConfigure = ''
      mkdir -p packages/ai/src/providers/data
      tar --extract --gzip --file=${modelData} \
        --directory=packages/ai/src/providers/data \
        --strip-components=4 \
        package/dist/providers/data
    '';

    # Build workspace deps in order, then the coding-agent. `telemetry` must
    # build before `ai` (ai's tsconfig.build.json resolves @earendil-works/pi-
    # telemetry to ../telemetry/dist), and `protocol`/`client` before the
    # coding-agent. The base derivation's buildPhase (from 0.75.4) omits
    # telemetry/protocol/client entirely, so it must be replaced wholesale.
    buildPhase = ''
      runHook preBuild

      npx tsgo -p packages/tui/tsconfig.build.json
      npx tsgo -p packages/telemetry/tsconfig.build.json
      npx tsgo -p packages/ai/tsconfig.build.json
      npx tsgo -p packages/agent/tsconfig.build.json
      npx tsgo -p packages/protocol/tsconfig.build.json
      npx tsgo -p packages/client/tsconfig.build.json
      npm run build --workspace=packages/coding-agent

      runHook postBuild
    '';

    dontNpmPrune = true;

    preInstall = ''
      npm prune --omit=dev --no-save
    '';

    # npm workspace symlinks in the output point into packages/ which doesn't
    # exist there. Replace the runtime workspace deps with built copies and
    # delete the rest. The base 0.75.4 postInstall only handled ai/agent-core/
    # tui; 0.84.x also needs client/protocol/telemetry.
    postInstall = ''
      local nm="$out/lib/node_modules/pi-monorepo/node_modules"

      for ws in @earendil-works/pi-ai:packages/ai \
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
    # postFixup wholesale) and add the 0.84.x env defaults.
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
