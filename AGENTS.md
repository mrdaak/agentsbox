# Agent Instructions

Infrastructure-only repo (no application source, no tests, no package manager for
this repo itself): Bash/nushell/Node scripts, a `Containerfile`, pinned-tool Nix
files, and a `flake.nix` that builds the user-facing `agentsbox` command. For
build/run usage and repo layout see `README.md`.

## Commands

| Task | Command |
|------|---------|
| Dev shell (sets `AGENTS_TOOLS_DIR`, prepends `bin/`) | `nix develop` |
| Build image | `nu make.nu build` |
| Force rebuild (no cache) + drop nix store volume | `nu make.nu update` |
| Run container in a project dir | `nu make.nu run --workdir <dir>` |
| Verify host env (nix, podman, image) | `nu make.nu doctor` |

No test suite exists — do not create placeholder test files. `nu make.nu
build`/`doctor` invoke podman and only run on the host; they do not work inside an
agentsbox container (no nested podman). When editing from inside the container,
make edits carefully and defer build/run verification to a host shell.

## External References

| Need | File |
|------|------|
| Build/run usage, repo layout, features | `README.md` |

## Conventions & Invariants

- **Rootless only:** never use `sudo` or run Podman as root.
- **Every `podman run`:** include `--rm` and `--security-opt no-new-privileges:true`.
- **Project hash parity:** `make.nu` `workdir-hash`, `bin/agentsbox` `sha1_8`, and
  `bin/list-secrets` all use SHA-1 (first 8 hex) of the canonical absolute workdir
  path. Do not change the algorithm without re-verifying all three.
- **Flake package:** `dontPatchShebangs = true` — scripts are `COPY`'d into a
  container with different nix store paths; patching shebangs breaks them.
- **Bash strict mode:** `set -euo pipefail` in every Bash script. Exception:
  `shell-entrypoint` uses only `set -e` (it re-execs through `nix develop` and
  runs fallback logic after failed commands).
- **Config is parsed, never sourced:** `.agentsbox/config.toml` and
  `~/.config/agentsbox.toml` are read with `nu`, never executed — a cloned repo
  must not run code at `enter` time.
- **`nu -c` TOML reads (Bash→nushell boundary only):** wrap in
  `2>/dev/null || true` for missing-key handling, but that also hides real parse
  errors — run the expression bare against a real TOML file first and confirm
  output before wrapping. Inside `.nu` files, do not spawn `nu -c`; use
  `try { open $file | get k } catch { fallback }` inline.
- **`installed_agents` is global-only** (`~/.config/agentsbox.toml`): the image
  is a host-level artifact shared by all projects. Fixed set
  `{claude, codex, pi, opencode}`; absent key → all four. Switching requires a
  rebuild.
- **`--a2a` is incompatible with a custom `network`** — `enter` aborts rather
  than run a broken A2A mesh. Under `host`/`container:` network modes, `--auth`
  and `--web` port publishing are skipped (Podman rejects them).
- **`[[volumes]]` validation:** `name` matches `^[A-Za-z0-9_.-]+$`; `target` is
  absolute and must not collide with a built-in mount (`/workspace`, `/nix`,
  `/root/.claude`, …). Malformed entries are hard errors. Read from both
  `.agentsbox/config.toml` (project, prefixed `agent-<hash>-<name>`) and
  `~/.config/agentsbox.toml` (global, prefixed `agent-global-<name>`); on a shared
  target the project mount wins (mirrors secrets).
- **Nushell list-typed flags** (`--foo: list<string>`) take a single `[a,b]`
  value, not repeated `--foo a --foo b`. Pass variable-length lists from Bash via
  env vars (one entry per line) — see `AGENTSBOX_VOLUMES` /
  `AGENTSBOX_GLOBAL_VOLUMES`.
- **`default (expr)` is eager** — use an `if` when the fallback has side effects.
- **Non-zero externals abort nushell** — wrap in `try { … } catch { … }` to
  convert to a custom message/exit.
- **Secrets are podman secrets**, never env vars or baked into
  `Containerfile`/`make.nu`. Project secrets are prefixed `agent-<hash>-<name>`,
  globals `agent-global-<name>`; on a shared mount target the project secret wins.
- **`:Z`** on all Podman bind mounts (SELinux-aware systems). Create host dirs
  with `mkdir -p` before mounting (`make.nu run` already does this).
- **Comments:** one-line header after the shebang stating *what* the file does;
  inline `#` only for non-obvious *why* (ordering deps, cross-file invariants,
  footgun guards). Never restate the code or leave commented-out code.

## Naming

- `bin/` scripts + config files: `kebab-case`, no extension.
- `make.nu`: `const` in `SCREAMING_SNAKE_CASE`; subcommands/helpers in
  `kebab-case`. Tasks are `export def "main <name>"`; helpers are plain `def`.
- Nix: `camelCase` (`buildInputs`, `shellHook`, `runtimeDeps`).
