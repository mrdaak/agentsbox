# Pin pi-coding-agent to a newer release than the nixpkgs channel currently ships.

{ pkgs ? import <nixpkgs> { } }:

let
  version = "0.83.0";

  srcHash = "sha256-+XRJua2TSXkZMnWtxtLMskSzEHrGEFFyvYcPATi7An4=";
  npmDepsHash = "sha256-AbSfP1Ion8bN309NUBQb1QSn2cIIUjNONmZgls9vnYE=";

  # Mirrors the upstream package.nix; bump this hash alongside version.
  modelData = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${version}.tgz";
    hash = "sha256-+YPCiiEgkwXtnCdJd+KRMPpNiEjfbN836QlNlcx7xtQ=";
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

  pi-coding-agent = pkgs.pi-coding-agent.overrideAttrs (old: {
    inherit version src npmDeps modelData;
    preConfigure = ''
      mkdir -p packages/ai/src/providers/data
      tar --extract --gzip --file=${modelData} \
        --directory=packages/ai/src/providers/data \
        --strip-components=4 \
        package/dist/providers/data
    '';
  });
in
{
  inherit pi-coding-agent;
}
