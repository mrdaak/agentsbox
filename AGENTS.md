# AGENTS.md — Coding Agent Instructions

This repository provisions and runs [OpenCode](https://opencode.ai/) inside a rootless
Podman container with a reproducible Nix-based dev environment. There is **no application
source code** to compile or test — the repo is purely operational infrastructure (Bash
and nushell scripts, a `make.nu` task runner, a Containerfile, and a Nix flake).

---

## Repository Layout

```
bin/                    User-facing scripts (opencode, opencode-update, opencode-entrypoint)
Containerfile           OCI image definition (based on nixos/nix:latest)
flake.nix               Nix flake — dev shell with podman + nushell
make.nu                 Orchestration (nushell): build / update / run subcommands
.opencode/              OpenCode agent config (package.json for plugins, plans/)
README.md               User-facing documentation
```

---

## Build Commands

All meaningful actions go through `make.nu` (a nushell task runner). The Nix dev
shell must be active (or `AGENTS_TOOLS_DIR` must be set) for subcommands that
reference the repo root.

```bash
# Enter the Nix dev shell (required once per terminal session)
nix develop
# or, if direnv is installed:
direnv allow

# Build the container image
nu make.nu build

# Force-rebuild the image without the layer cache
nu make.nu update

# Run the agent in a specific project directory
nu make.nu run --workdir ~/src/my-project
```

In normal use you go through `agentsbox`, which calls `make.nu` for you:

```bash
agentsbox enter     # equivalent to: nu make.nu run --workdir $PWD
agentsbox update    # equivalent to: nu make.nu update
```

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
```

---

## Linting / Formatting

There are no linting or formatting tools configured in this repository. Follow the
conventions below when editing shell scripts or `make.nu` subcommands.

---

## Code Style Guidelines

### Shell Scripts (`bin/`)

- **Shebang:** always `#!/usr/bin/env bash`.
- **Strict mode:** use `set -euo pipefail` at the top of every script.
  - Exception: `opencode-entrypoint` uses only `set -e` because it needs to run
    fallback logic after a failed command — `-u` and `-o pipefail` would interfere.
- **Variable naming:** `SCREAMING_SNAKE_CASE` for all variables.
- **Repo-root resolution:** use the portable idiom:
  ```bash
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  ```
- **Process replacement:** prefer `exec <command>` instead of a bare call when the
  script's only job is to hand off to another process (avoids a wasted shell process).
- **Single responsibility:** each script does one thing and defers logic to `make.nu`.
- **Comments:** one-line header comment immediately after the shebang explaining purpose.
- **Graceful fallback pattern** (entrypoint only):
  ```bash
  some-command "$@" || {
      echo "Warning: <reason>, falling back"
      fallback-command "$@"
  }
  ```

### make.nu (nushell)

- **Constant naming:** `SCREAMING_SNAKE_CASE` for `const` values (e.g., `IMAGE_NAME`,
  `NIX_VOLUME`); `kebab-case` for command and helper names (`build-image`, `secret-flags`).
- **Subcommands:** expose each task as `export def "main <name>" []`; keep non-task
  helpers as plain (unexported) `def`s.
- **Mandatory argument validation:** check required flags explicitly and exit non-zero:
  ```nu
  if ($workdir | is-empty) {
      print -e "WORKDIR is not set. Usage: nu make.nu run --workdir ~/src/my-project"
      exit 1
  }
  ```
- **External-command failures:** a non-zero external aborts the script — wrap in
  `try { ... } catch { ... }` when you need to convert that into a custom message/exit.
- **Eager `default`:** `default (expr)` evaluates `expr` unconditionally; use an `if`
  when the fallback has side effects (e.g. raising an error).
- **Comments:** use `##` prefix on the line above a subcommand for self-documentation.
- **Security:** always pass `--security-opt no-new-privileges:true` to `podman run`.
- **Ephemeral containers:** always include `--rm` in `podman run` invocations.
- **Container naming:** derive from the project directory — `agent-(basename)-(hash)`
  — so multiple projects can run simultaneously without name collisions.

### Containerfile

- **Base image:** `nixos/nix:latest` (pinned at build time via Nix channels).
- **Group related `RUN` steps** with `&&` and `\` line continuations to minimize layers.
- **ENV before COPY/RUN** for variables that influence subsequent steps.
- **XDG compliance:** always set `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, and any
  app-specific config dir (`OPENCODE_CONFIG_DIR`) so tools find their config correctly.
- **Permissions:** `chmod +x` any copied script in the same `RUN` step or immediately
  after `COPY`.
- **`git config --system safe.directory /workspace`** must be present so git works on
  the bind-mounted project directory.

### Nix (`flake.nix`)

- **Attribute naming:** `camelCase` following Nix conventions (`buildInputs`, `shellHook`,
  `devShells`).
- **`shellHook`:** export `AGENTS_TOOLS_DIR` and prepend `bin/` to `$PATH` so wrapper
  scripts are available in any shell.
- **Pin nixpkgs channel:** reference a stable channel (e.g., `nixos-25.05`) to ensure
  reproducible builds.

### File Naming

- Scripts and config files: `kebab-case` (e.g., `opencode-entrypoint`).
- `make.nu` subcommands: lowercase, `kebab-case` (`build`, `update`, `run`, `clean-nix-store`).
- No file extensions on executable shell scripts in `bin/`.

---

## Volume Mount Conventions

When modifying the `run` subcommand in `make.nu`, preserve these bind mounts:

| Host path              | Container path                | Purpose                  |
|------------------------|-------------------------------|--------------------------|
| `$(WORKDIR)`           | `/workspace`                  | Project source (rw)      |
| `~/.opencode/config`   | `/root/.config/opencode`      | Persistent agent config  |
| `~/.opencode/data`     | `/root/.local/share/opencode` | Persistent agent data    |

Always create host-side directories with `mkdir -p` before mounting them.

---

## Environment Variables

| Variable              | Set by        | Purpose                                      |
|-----------------------|---------------|----------------------------------------------|
| `AGENTS_TOOLS_DIR`    | `flake.nix` shellHook | Absolute path to repo root; used by `make.nu` |
| `XDG_CONFIG_HOME`     | Containerfile + `make.nu` `-e` | Overrides XDG base dir for config |
| `XDG_DATA_HOME`       | Containerfile + `make.nu` `-e` | Overrides XDG base dir for data   |
| `OPENCODE_CONFIG_DIR` | Containerfile + `make.nu` `-e` | Explicit OpenCode config path     |

---

## Do / Do Not

**Do:**
- Keep scripts minimal and single-purpose; delegate logic to `make.nu`.
- Run `nu make.nu build` after any change to the `Containerfile` to verify it builds.
- Use `:Z` on SELinux-aware systems for all Podman bind mounts.
- Create `~/.opencode/config` and `~/.opencode/data` on the host before mounting.

**Do not:**
- Add application source code, compiled languages, or a package manager (npm/pip/cargo)
  to this repository — it is purely infrastructure.
- Commit `bun.lock` or the generated `.opencode/package.json`; they are git-ignored.
- Use `sudo` or run Podman as root — rootless is a hard requirement.
- Cache secrets or API keys in the `Containerfile` or `make.nu`.
- Skip `set -euo pipefail` in new Bash scripts without explicit justification.
