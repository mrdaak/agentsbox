---
name: nix-project-setup
description: Use when the user asks to add, initialize, create, scaffold, or set up a minimal Nix flake for a programming project that does not already have flake.nix. Detect common project runtimes such as JavaScript/TypeScript or Go, honor explicit runtime and package-manager version files or package metadata when present, and create only a basic flake.nix with runtime and package-manager dependencies installed as a foundation for later expansion.
---

# Minimal Nix project setup

Create the smallest useful `flake.nix` for a programming project that does not
already have one. Do not add build logic, formatters, linters, extra dev tools,
shells beyond the default shell, lock files, or project-specific automation
unless the user explicitly asks for more.

## Workflow

1. Check for `flake.nix` at the project root.
   - If it exists, stop and tell the user no new flake was created.
   - Do not overwrite or expand an existing flake unless the user explicitly
     asks.
2. Decide whether the directory is a programming project.
   - JavaScript/TypeScript: `package.json`, lockfiles, `tsconfig.json`, or common
     source files.
   - Go: `go.mod`, `go.sum`, or common Go source files.
   - If no supported runtime is clear, stop and ask for the intended runtime.
3. Look for explicit runtime and package-manager versions before choosing a
   default.
   - JavaScript/TypeScript: `.node-version`, `.nvmrc`, `package.json` fields
     `engines.node`, `devEngines.runtime.version`, `packageManager`, or
     package-manager-specific metadata that clearly implies Node.
   - Go: `go.mod` `go` directive and `toolchain` directive.
4. Pick the Nix packages.
   - Prefer the closest available pinned runtime package in `nixpkgs` when the
     version is explicit, such as `nodejs_20`, `nodejs_22`, `go_1_22`, or
     `go_1_23`.
   - If the exact patch version is not available, choose the matching major
     runtime package when possible.
   - If no version is specified, use the stable default package, such as
     `nodejs` for JavaScript/TypeScript or `go` for Go.
   - For JavaScript/TypeScript, also install the package manager indicated by
     `packageManager`, lockfiles, or project metadata. Use `pkgs.pnpm`,
     `pkgs.yarn`, `pkgs.bun`, or rely on Node's bundled `npm` when npm is the
     manager. If a versioned package-manager attribute is available, use the
     closest match; otherwise use the stable default package-manager attribute.
     If no package manager is clear, install only Node because npm is included
     with Node.
5. Write a minimal `flake.nix` with only the selected runtime and package
   manager packages in `devShells.default`.

## JavaScript/TypeScript Template

Use this shape, replacing `nodejs` with the selected Node package if a supported
version was found. This example shows a pnpm project; omit `pkgs.pnpm` or replace
it with the detected package manager as appropriate:

```nix
{
  description = "Development shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.nodejs
              pkgs.pnpm
            ];
          };
        });
    };
}
```

For npm projects, do not add a separate npm package unless there is a clear
local reason; `pkgs.nodejs` normally provides npm. For pnpm, yarn, or bun
projects, include the matching package manager package. Do not add install
commands, hooks, aliases, or package-manager setup beyond the dependency itself.

## Go Template

Use this shape, replacing `go` with the selected Go package if a supported
version was found:

```nix
{
  description = "Development shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.go
            ];
          };
        });
    };
}
```

## Version Mapping Notes

- Parse semver ranges conservatively. `>=20`, `^20.11.0`, `20.x`, and
  `20.11.0` all indicate Node 20. `>=20 <23` indicates the lowest compatible
  major that has a matching stable Nix package unless the project gives a more
  specific preference elsewhere.
- For `.nvmrc` values like `lts/*`, `node`, or `stable`, use `pkgs.nodejs`.
- For JavaScript package managers, prefer `package.json` `packageManager`, then
  lockfiles: `pnpm-lock.yaml` means `pkgs.pnpm`, `yarn.lock` means `pkgs.yarn`,
  `package-lock.json` or `npm-shrinkwrap.json` means npm via `pkgs.nodejs`,
  and `bun.lock` or `bun.lockb` means `pkgs.bun`.
- For `packageManager` values like `pnpm@9.12.0`, `yarn@4.5.0`, or `bun@1.1.0`,
  preserve the package-manager choice. Pin the major version only when a matching
  Nix package attribute is readily available; otherwise use the stable package.
- For Go, prefer `toolchain go1.N.P` over the `go 1.N` directive when both are
  present. Otherwise use the `go` directive's major/minor.
- Do not run online searches to discover the latest runtime. Use available
  `nixpkgs` attributes or the stable default package.
