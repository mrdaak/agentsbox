# AGENTS.md — Coding Agent Instructions

This repository is **agentsbox**: a Nix-packaged tool that runs AI coding agents
(Claude Code, OpenCode, Codex, Pi) in a secure, rootless Podman container with
a reproducible Nix-based environment. There is **no application source code** to
compile or test — the repo is purely operational infrastructure (Bash, nushell,
and Node scripts, a `make.nu` task runner, a Containerfile, pinned-tool Nix
files, and a flake that builds the user-facing `agentsbox` command).

The built `agentsbox` binary is published as a Nix flake package
(`github:mrdaak/agentsbox`); users install it once and run `agentsbox enter`
from any project directory.

---

## Repository Layout

```
bin/                      User-facing scripts
  agentsbox               Dispatcher: enter / ls / secrets / install-skills / config / update / doctor
  shell-entrypoint        In-container entrypoint: nix-shell re-exec + Zellij/web/A2A setup
  doctor                  Host environment checks (nix, podman, image)
  list                    `agentsbox ls` — running containers, boxes/network view, --watch
  list-secrets            `agentsbox secrets ls` — list project/global podman secrets
  listen-message          A2A server (Node, stdlib only): JSON-RPC message/send over HTTP
  send-message            A2A client: post a message/send to another agent, print the reply
  codex-container         codex wrapper: bypasses nested sandbox for `codex exec` only
Containerfile             OCI image (pinned ghcr.io/nixos/nix, nix profile from packages.nix)
flake.nix                 Nix flake — builds the `agentsbox` package + a dev shell
flake.lock                Pinned flake inputs
packages.nix              Source of truth for every tool installed into the image
claude-code.nix           Pinned Claude Code (prebuilt binary, overrideAttrs)
codex.nix                 Pinned OpenAI Codex CLI (prebuilt musl binary, stdenv derivation)
pi.nix                    Pinned pi-coding-agent (buildNpmPackage overrideAttrs)
make.nu                   Orchestration (nushell): build / run / update / shell / doctor / clean
zellij-config.kdl         Baked-in Zellij config (locked mode, no release notes/tips)
skills/                   Bundled skills (SKILL.md), installed via `agentsbox install-skills`
  agentsbox-ask-agent/      A2A skill: ask another project's agent a question
  scaffold-minimal-flake/  Skill: scaffold a minimal flake.nix for a new project
README.md                 User-facing documentation
```

---

## Build Commands

All meaningful actions go through `make.nu` (a nushell task runner). The Nix dev
shell (or the built `agentsbox` package) sets `AGENTS_TOOLS_DIR`, which `make.nu`
reads to locate the repo root (Containerfile, bin scripts).

```bash
# Enter the Nix dev shell (required once per terminal session when hacking on this repo)
nix develop

# Build the container image (podman build; layers are cached)
nu make.nu build

# Force-rebuild without cache and drop the runtime Nix store volume
nu make.nu update

# Run the agent container in a specific project directory
nu make.nu run --workdir ~/src/my-project
```

In normal use you go through the installed `agentsbox` command, which calls
`make.nu` for you:

```bash
agentsbox enter                 # equivalent to: nu make.nu run --workdir $PWD
agentsbox update                # equivalent to: nu make.nu update
agentsbox enter --a2a           # enable agent-to-agent messaging
agentsbox enter --web           # serve Zellij's web client in a browser
agentsbox enter --agent claude  # auto-launch claude in the session
```

`make.nu run` flags (the full set `bin/agentsbox` builds up):

| Flag                         | Purpose                                                         |
| ---------------------------- | --------------------------------------------------------------- |
| `--workdir <dir>`            | Host project dir mounted at `/workspace` (required)             |
| `--auth`                     | Bind host port 1455:1455 for OpenCode auth flows                |
| `--a2a`                      | Join `agentsbox-net`, start the A2A listener                    |
| `--a2a-agent <name>`         | Headless agent answering A2A messages (default `claude`)         |
| `--agent-name <name>`        | A2A alias (default: workdir basename)                           |
| `--agent <name>`             | Interactive agent to auto-launch in the session                  |
| `--web`                      | Serve Zellij's web client on the host                            |
| `--web-port <int>`           | Host port mapped to container 8082                              |
| `--web-bind <addr>`          | Host address the web port binds to (default `127.0.0.1`)         |

---

## Test Commands

**This repository has no test suite.** There are no test files, no test runner, and no
test-related subcommands. Do not create placeholder test files.

Verification is done by building and running the container:

```bash
# Smoke-test: build succeeds
nu make.nu build

# Smoke-test: container launches and prints usage
nu make.nu run --workdir /tmp

# Smoke-test: host environment is ready
nu make.nu doctor
```

---

## Linting / Formatting

There are no linting or formatting tools configured in this repository. Follow the
conventions below when editing scripts or `make.nu` subcommands.

### Commenting

Comments are for the **why**, not the **what**. Apply this everywhere (Bash,
nushell, Node, TOML):

- One header comment immediately after the shebang: a single line stating what
  the file does — not how. Wrap to a second line only if essential, then stop.
- Inline `#` notes explain **non-obvious** behavior only: a subtle ordering
  dependency, a cross-file invariant that must hold (e.g. the project-hash
  parity across `make.nu` / `bin/agentsbox` / `bin/list-secrets`), or a guard
  against a footgun. If the code reads itself, leave it alone.
- Never restate the code (`# create the dir` above `mkdir -p`), never narrate a
  block step-by-step, and never leave commented-out code.
- Keep notes terse — one line, declarative. `scripts/smoke-volumes.sh` is the
  reference example: a one-line header, and only the hash-parity line and the
  stub's purpose are annotated.

---

## Code Style Guidelines

### Shell Scripts (`bin/`)

- **Shebang:** `#!/usr/bin/env bash` for Bash, `#!/usr/bin/env nu` for nushell,
  `#!/usr/bin/env node` for Node scripts (the A2A server/client).
- **Strict mode:** `set -euo pipefail` at the top of every Bash script.
  - Exception: `shell-entrypoint` uses only `set -e` because it re-execs itself
    through `nix develop` and runs fallback logic after a failed command — `-u`
    and `-o pipefail` would interfere.
- **Variable naming:** `SCREAMING_SNAKE_CASE` for all variables.
- **Repo-root resolution:** use the portable idiom:
  ```bash
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  ```
- **Hand-off:** prefer `exec <command>` (`exec nu "$SCRIPT_DIR/make.nu" ...`,
  `exec "$SCRIPT_DIR/bin/list" ...`) when the script's only job is to hand off
  to another process.
- **Single responsibility:** `bin/agentsbox` dispatches and delegates; heavy
  logic lives in `make.nu` or the dedicated bin scripts.
- **Comments:** follow the repo-wide **Commenting** rules above (header line
  states *what*; inline `#` notes explain non-obvious *why* only).
- **Graceful fallback pattern** (entrypoint):
  ```bash
  some-command "$@" || {
      echo "Warning: <reason>, falling back"
      fallback-command "$@"
  }
  ```
- **`nu -c` helpers (TOML reads):** the established pattern (`config_value`,
  `config_volumes`) invokes `nu -c '...'` from a Bash function to *parse*
  `.agentsbox/config.toml` (never source it — a cloned repo must not run code at
  `enter` time), with `2>/dev/null || true` so a missing file/key yields empty
  output. That suppression **also hides real parse errors in a new expression**
  (a broken `nu -c` exits 0 empty and looks like a missing-key case). So when
  writing or changing such a helper, **run the nushell expression bare first**
  (`nu -c '<expr>'` against a real TOML file) and confirm it prints the right
  thing *before* wrapping it in the Bash function with the suppression. Keep the
  expression quote-light and minimal; if it needs conditionals/`each`/`default`
  together it has outgrown an inline `nu -c` — move it to an exported `def` in
  `make.nu` instead.

### make.nu (nushell)

- **Constant naming:** `SCREAMING_SNAKE_CASE` for `const` values (`IMAGE_NAME`,
  `NIX_VOLUME`, `PNPM_VOLUME`, `A2A_NET`); `kebab-case` for command and helper
  names (`build-image`, `secret-flags`, `workdir-hash`).
- **Subcommands:** expose each task as `export def "main <name>" [...]`; keep
  non-task helpers as plain (unexported) `def`s.
- **Mandatory argument validation:** check required flags explicitly and exit
  non-zero:
  ```nu
  if ($workdir | is-empty) {
      print -e "WORKDIR is not set. Usage: nu make.nu run --workdir ~/src/my-project"
      exit 1
  }
  ```
- **External-command failures:** a non-zero external aborts the script — wrap
  in `try { ... } catch { ... }` when you need to convert that into a custom
  message/exit (see `build-image`).
- **Eager `default`:** `default (expr)` evaluates `expr` unconditionally; use an
  `if` when the fallback has side effects.
- **List-typed flags take a single `[a, b]` value, not repeated flags:** a
  `--foo: list<string>` param cannot be fed with `--foo a --foo b` (nushell
  raises `expected list`); it wants `--foo "[a,b]"`. When `bin/agentsbox` (Bash)
  needs to pass a variable-length list into `make.nu`, prefer an **env var**
  (one entry per line) over a list-typed flag — see `AGENTSBOX_VOLUMES`, which
  `volume-flags` reads via `$env.AGENTSBOX_VOLUMES? | default "" | lines`. This
  matches how the codebase already moves state into `make.nu` (`AGENT_NAME`,
  `A2A_AGENT`, …).
- **Comments:** `##` prefix on the line above a subcommand for
  self-documentation; plain `#` for implementation notes. Otherwise follow the
  repo-wide **Commenting** rules (why, not what).
- **Security:** always pass `--security-opt no-new-privileges:true` to
  `podman run`.
- **Ephemeral containers:** always include `--rm` in `podman run` invocations.
- **Container naming:** derive from the project directory —
  `agent-(basename)-(hash)` (first 8 hex of the SHA-1 of the canonical
  workdir path) — so multiple projects run simultaneously without collisions.
- **Project hash:** must match between `make.nu`'s `workdir-hash`,
  `bin/agentsbox`'s `sha1_8`, and `bin/list-secrets` — all use SHA-1 of the
  canonical absolute path, first 8 hex. Do not change the hashing without
  re-verifying all three.

### Containerfile

- **Base image:** pinned `ghcr.io/nixos/nix:<version>@sha256:<digest>` (not
  `nixos/nix:latest`) for reproducibility. The built image is tagged
  `agentsbox:<agentsbox-version>` and `agentsbox:latest` (the version tag is a
  rollback target; `run`/`doctor` resolve the versioned tag via
  `AGENTSBOX_VERSION`).
- **Tools via `packages.nix`:** install all dev tools in a single
  `nix profile add --priority 4 -f /tmp/nix/packages.nix`; `packages.nix` is the
  source of truth and imports the pinned `claude-code.nix`, `codex.nix`, and
  `pi.nix`. `--priority 4` resolves collisions with the base image's profile.
- **Group related `RUN` steps** with `&&` and `\` line continuations to
  minimize layers.
- **ENV before COPY/RUN** for variables that influence subsequent steps.
- **XDG compliance:** set `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, and
  `OPENCODE_CONFIG_DIR` so tools find their config correctly.
- **Permissions:** `chmod +x` every copied script in the same `RUN` step.
- **`git config --system safe.directory /workspace`** must be present so git
  works on the bind-mounted project directory.
- **`dontPatchShebangs`:** the flake package must NOT rewrite shebangs — scripts
  are `COPY`'d into the container whose nix store has different store paths, so
  a patched `#!/usr/bin/env bash` (pointing at host nix store) would break
  inside the container.
- **Bake in config that can't be bind-mounted across hosts:** the Zellij config
  is `COPY`'d in (on macOS, podman runs in a VM that can't see the host's
  `/nix/store`, so a runtime bind-mount of the nix-packaged config fails).

### Nix (`flake.nix`, `packages.nix`, pinned-tool files)

- **Attribute naming:** `camelCase` following Nix conventions (`buildInputs`,
  `shellHook`, `devShells`, `runtimeDeps`).
- **Flake package:** `flake.nix` builds `packages.default` / `packages.agentsbox`
  — a `stdenv.mkDerivation` that wraps `bin/agentsbox` with `makeWrapper`,
  sets `AGENTS_TOOLS_DIR` to the installed `share/agents` dir, and prepends
  runtime deps (`nushell`, `jq`, `coreutils`) to `PATH`.
- **Pinned tool files:** `claude-code.nix`, `codex.nix`, `pi.nix` each pin a
  specific upstream release decoupled from the nixpkgs channel:
  - `claude-code.nix`: `overrideAttrs` on `pkgs.claude-code`, swapping version
    + a per-platform `fetchurl` of the prebuilt binary.
  - `codex.nix`: a fresh `stdenv.mkDerivation` installing OpenAI's prebuilt
    musl release tarball (single binary).
  - `pi.nix`: `overrideAttrs` on `pkgs.pi-coding-agent`, swapping version +
    `src` + a `fetchNpmDeps` hash.
  - To upgrade: bump `version`, build once with `pkgs.lib.fakeHash`, and let
    Nix print the real hash.
- **Pin nixpkgs channel:** `flake.nix` references a stable channel
  (e.g. `nixos-25.11`); `packages.nix` fetches its own tarball (e.g.
  `nixos-26.05`) so the image tool set is pinned independently of the user's
  channels.
- **`shellHook`:** export `AGENTS_TOOLS_DIR` and prepend `bin/` to `$PATH` so
  wrapper scripts are available in any shell.

### File Naming

- Scripts and config files: `kebab-case` (`shell-entrypoint`, `codex-container`).
- `make.nu` subcommands: lowercase, `kebab-case`
  (`build`, `run`, `update`, `shell`, `doctor`, `clean-nix-store`,
  `clean-pnpm-store`).
- No file extensions on executable shell scripts in `bin/`.

---

## Volume Mount Conventions

When modifying the `run` subcommand in `make.nu`, preserve these bind mounts:

| Host path                | Container path                | Purpose                          |
| ------------------------ | ----------------------------- | -------------------------------- |
| `$(WORKDIR)`             | `/workspace`                  | Project source (rw)              |
| `agent-nix-store` volume | `/nix`                        | Persistent Nix store across runs  |
| `agent-pnpm-store` volume| `/pnpm-store`                 | Persistent pnpm store            |
| `~/.agents`              | `/root/.agents`               | Shared skills store              |
| `~/.pi/agent`            | `/root/.pi/agent`             | Pi agent config/data             |
| `~/.opencode/config`     | `/root/.config/opencode`     | OpenCode persistent config       |
| `~/.opencode/data`       | `/root/.local/share/opencode`| OpenCode persistent data         |
| `~/.claude`              | `/root/.claude`              | Claude Code config               |
| `~/.claude.json`         | `/root/.claude.json`         | Claude Code state                |
| `~/.codex`               | `/root/.codex`               | Codex config                     |
| `~/.config/codex`        | `/root/.config/codex`        | Codex config                     |
| `~/.local/share/codex`   | `/root/.local/share/codex`   | Codex data                       |
| podman secrets           | `agents.target` label path    | Project/global credential files  |
| `agent-<hash>-<name>` volume | `[[volumes]].target`        | Project-declared persistent volume (see below) |

Always create host-side directories with `mkdir -p` before mounting them
(`make.nu run` does this). Use `:Z` on SELinux-aware systems for all bind
mounts.

### Project-declared volumes

A project may declare persistent named volumes in `.agentsbox/config.toml` via a
`[[volumes]]` array-of-tables (two fields: `name`, `target`). On `agentsbox enter`
agentsbox creates each volume (namespaced `agent-<hash>-<name>`, matching the
secret convention) and mounts it at `target` with `:Z`. The config is *parsed*
(never sourced), so a cloned repo can't run code at `enter` time.

```toml
[[volumes]]
name   = "go-cache"
target = "/root/go"
```

`name` must match `^[A-Za-z0-9_.-]+$`; `target` must be absolute and must not
collide with a built-in mount (`/workspace`, `/nix`, `/root/.claude`, …). Malformed
entries are hard errors. Validation, namespacing, and `podman volume create` happen
in `make.nu`'s `volume-flags` helper; the `[[volumes]]` array is read in
`bin/agentsbox` (`config_volumes`) and transported to `make.nu` via the
`AGENTSBOX_VOLUMES` env var (one `name:target` per line), since nushell list flags
don't accept repeated values.

---

## Environment Variables

| Variable              | Set by                            | Purpose                                              |
| --------------------- | --------------------------------- | ---------------------------------------------------- |
| `AGENTS_TOOLS_DIR`    | `flake.nix` (wrapper + shellHook) | Absolute path to installed share/agents; used by `make.nu` |
| `AGENTSBOX_VERSION`   | `flake.nix` (wrapper + shellHook) | agentsbox version — pins the podman image tag (`agentsbox:<version>`) |
| `AGENTSBOX_VOLUMES`   | `bin/agentsbox` (`enter`)         | Project-declared `[[volumes]]` (one `name:target` per line); read by `make.nu` |
| `XDG_CONFIG_HOME`     | Containerfile + `make.nu` `-e`    | `/root/.config`                                      |
| `XDG_DATA_HOME`       | Containerfile + `make.nu` `-e`    | `/root/.local/share`                                 |
| `OPENCODE_CONFIG_DIR` | Containerfile + `make.nu` `-e`    | `/root/.config/opencode`                             |
| `AGENT_NAME`          | `make.nu run` `-e`                | A2A alias + Zellij session name                      |
| `AGENTSBOX_AGENT`     | `make.nu run` `-e`                | Agent to auto-launch in the session (read by entrypoint) |
| `A2A_ENABLED`         | `make.nu run` `-e`                | Starts the A2A listener in the entrypoint            |
| `A2A_AGENT`           | `make.nu run` `-e`                | Headless agent answering A2A messages                |
| `WEB_ENABLED`         | `make.nu run` `-e`                | Starts the Zellij web client + socat relay           |
| `WEB_PORT`            | `make.nu run` `-e`                | Host port for the web client (printed in the URL)   |
| `WEB_HOST`            | `make.nu run` `-e`                | Host address for the web URL                         |

---

## Secrets

Secrets are podman secrets (not env vars), loaded via `agentsbox secrets add`
and mounted read-only into the agent shell at the `agents.target` label path.
Project secrets are prefixed `agent-<hash>-<name>`; globals are
`agent-global-<name>`. At run time `make.nu`'s `secret-flags` collects both
(matching by name prefix), resolves the mount target from the
`agents.target` label, and on a shared target the project secret wins
(`uniq-by target` keeps the first occurrence). Do not cache secrets or API
keys in the Containerfile or `make.nu`.

---

## Do / Do Not

**Do:**
- Keep scripts minimal and single-purpose; delegate logic to `make.nu` or the
  dedicated bin scripts.
- Run `nu make.nu build` after any change to the `Containerfile` or
  `packages.nix` to verify it builds.
- Use `:Z` on SELinux-aware systems for all Podman bind mounts.
- Create the host config dirs (`~/.opencode/{config,data}`, `~/.claude`, etc.)
  before mounting; `make.nu run` already does `mkdir -p`.
- Keep the project hash in sync across `make.nu` (`workdir-hash`),
  `bin/agentsbox` (`sha1_8`), and `bin/list-secrets` — they must agree.
- Run `agentsbox doctor` (or `nu make.nu doctor`) to verify the host has Nix,
  Podman, and the image.

**Do not:**
- Add application source code, compiled languages, or a package manager
  (npm/pip/cargo) *for this repo itself* — it is purely infrastructure.
- Patch shebangs in the `agentsbox` flake package (`dontPatchShebangs = true`) —
  it breaks the in-container scripts.
- Use `sudo` or run Podman as root — rootless is a hard requirement.
- Cache secrets or API keys in the `Containerfile` or `make.nu`.
- Skip `set -euo pipefail` in new Bash scripts without explicit justification
  (the `shell-entrypoint` `set -e`-only exception is documented above).
- Change the project-hashing algorithm without re-verifying all three call sites.
