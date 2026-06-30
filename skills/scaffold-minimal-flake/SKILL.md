---
name: scaffold-minimal-flake
description: Use when the user asks to scaffold a minimal Nix flake for a project that does not have one.
---

# Scaffold a minimal Nix flake

Create the smallest useful `flake.nix` for a programming project. Add only the runtime and package manager to `devShells.default`. Do not add build logic, formatters, linters, extra dev tools, additional shells, lock files, or project-specific automation unless the user explicitly asks.

## Steps

1. **Guard.** Check for `flake.nix` at the project root.
   - **Completion criterion:** if it exists, stop and tell the user no new flake was created. Do not overwrite or expand it unless the user explicitly asks.

2. **Detect runtime.**
   - JavaScript/TypeScript: `package.json`, lockfiles, `tsconfig.json`, or common source files.
   - Go: `go.mod`, `go.sum`, or common Go source files.
   - **Completion criterion:** a supported runtime is identified, or you stop and ask for the intended runtime.

3. **Read version hints.**
   - JavaScript/TypeScript: `.node-version`, `.nvmrc`, `package.json` `engines.node`, `devEngines.runtime.version`, or `packageManager`.
   - Go: `go.mod` `go` directive and `toolchain` directive.
   - **Completion criterion:** you have extracted an explicit version preference or confirmed none exists.

4. **Map to Nix packages.**
   - Default to the `nixos-26.05` channel. If the selected runtime or package-manager version is not available there, use `nixos-unstable` instead and tell the user.
   - Prefer the closest available pinned runtime attribute (`nodejs_20`, `nodejs_22`, `go_1_22`, `go_1_23`, etc.).
   - If only a major version is clear, use the matching major attribute.
   - If no version is specified, use the stable default (`nodejs` or `go`).
   - For JavaScript/TypeScript, add the detected package manager (`pnpm`, `yarn`, `bun`, or npm via `nodejs`). If none is clear, install only `nodejs`.
   - **Completion criterion:** the package list and channel are selected and no wider than runtime + one package manager.

5. **Write `flake.nix`.**
   - **Completion criterion:** the file exists at the project root, uses the shape below, and contains only the selected packages in `devShells.default`.

## Template

Replace `<!-- runtime -->` and optionally `<!-- package-manager -->` with the selected packages:

```nix
{
  description = "Development shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

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
              <!-- runtime -->
              <!-- package-manager -->
            ];
          };
        });
    };
}
```

For npm projects, omit the package-manager line; `pkgs.nodejs` already provides npm.

## Version mapping

- `>=20`, `^20.11.0`, `20.x`, `20.11.0` → Node 20. `>=20 <23` → lowest matching major with a stable Nix package.
- `.nvmrc` values like `lts/*`, `node`, or `stable` → `pkgs.nodejs`.
- `packageManager` priority: `package.json` field, then lockfiles (`pnpm-lock.yaml`, `yarn.lock`, `package-lock.json`/`npm-shrinkwrap.json`, `bun.lock`/`bun.lockb`).
- `packageManager` values like `pnpm@9.12.0` → preserve the tool; pin the major only when a matching Nix attribute exists.
- Go: prefer `toolchain go1.N.P` over `go 1.N`.
- Do not search online for the latest runtime. Use available `nixpkgs` attributes or the stable default; fall back to `nixos-unstable` only when the selected version is missing from `nixos-26.05`.

## Maintenance

Update the default `nixos-26.05` channel in this skill when a newer stable NixOS release becomes the project's standard pin.
