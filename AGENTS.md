# AGENTS.md — Coding Agent Instructions

This repository provisions and runs [OpenCode](https://opencode.ai/) inside a rootless
Podman container with a reproducible Nix-based dev environment. There is **no application
source code** to compile or test — the repo is purely operational infrastructure (Bash
scripts, a Makefile, a Containerfile, and a Nix flake).

---

## Repository Layout

```
bin/                    User-facing scripts (opencode, opencode-update, opencode-entrypoint)
Containerfile           OCI image definition (based on nixos/nix:latest)
flake.nix               Nix flake — dev shell with gnumake + podman
Makefile                Orchestration: build / update / run targets
.opencode/              OpenCode agent config (package.json for plugins, plans/)
README.md               User-facing documentation
```

---

## Build Commands

All meaningful actions go through `make`. The Nix dev shell must be active (or
`OPENCODE_TOOLS_DIR` must be set) for `make` targets that reference `${ROOT_PATH}`.

```bash
# Enter the Nix dev shell (required once per terminal session)
nix develop
# or, if direnv is installed:
direnv allow

# Build the container image
make build

# Force-rebuild the image without the layer cache
make update

# Run OpenCode in a specific project directory
make run WORKDIR=~/src/my-project

# Pass extra arguments to OpenCode
make run WORKDIR=~/src/my-project ARGS="--model gpt-4o"
```

The convenience wrappers in `bin/` delegate directly to `make`:

```bash
opencode            # equivalent to: make run WORKDIR=$PWD
opencode-update     # equivalent to: make update
```

---

## Test Commands

**This repository has no test suite.** There are no test files, no test runner, and no
test-related Makefile targets. Do not create placeholder test files.

Verification is done by building and running the container:

```bash
# Smoke-test: build succeeds
make build

# Smoke-test: container launches and prints usage
make run WORKDIR=/tmp
```

---

## Linting / Formatting

There are no linting or formatting tools configured in this repository. Follow the
conventions below when editing shell scripts or Makefile targets.

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
- **Single responsibility:** each script does one thing and defers logic to `make`.
- **Comments:** one-line header comment immediately after the shebang explaining purpose.
- **Graceful fallback pattern** (entrypoint only):
  ```bash
  some-command "$@" || {
      echo "Warning: <reason>, falling back"
      fallback-command "$@"
  }
  ```

### Makefile

- **Variable naming:** `SCREAMING_SNAKE_CASE` (e.g., `IMAGE_NAME`, `ROOT_PATH`).
- **Phony targets:** declare all non-file targets in `.PHONY`.
- **Shell:** set `SHELL := /bin/bash` at the top for consistent behavior.
- **Mandatory variable validation:** use `$(error ...)` inside `ifndef` blocks:
  ```makefile
  ifndef WORKDIR
      $(error WORKDIR is not set. Usage: make run WORKDIR=~/src/my-project)
  endif
  ```
- **Comments:** use `##` prefix on the line above a target for self-documenting targets.
- **Security:** always pass `--security-opt no-new-privileges:true` to `podman run`.
- **Ephemeral containers:** always include `--rm` in `podman run` invocations.
- **Container naming:** derive from the project directory — `opencode-$(notdir $(WORKDIR))`
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
- **`shellHook`:** export `OPENCODE_TOOLS_DIR` and prepend `bin/` to `$PATH` so wrapper
  scripts are available in any shell.
- **Pin nixpkgs channel:** reference a stable channel (e.g., `nixos-25.05`) to ensure
  reproducible builds.

### File Naming

- Scripts and config files: `kebab-case` (e.g., `opencode-entrypoint`).
- Make targets: lowercase single words (`build`, `update`, `run`, `shell`).
- No file extensions on executable shell scripts in `bin/`.

---

## Volume Mount Conventions

When modifying the `make run` target, preserve these bind mounts:

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
| `OPENCODE_TOOLS_DIR`  | `flake.nix` shellHook | Absolute path to repo root; used by Makefile |
| `XDG_CONFIG_HOME`     | Containerfile + Makefile `-e` | Overrides XDG base dir for config |
| `XDG_DATA_HOME`       | Containerfile + Makefile `-e` | Overrides XDG base dir for data   |
| `OPENCODE_CONFIG_DIR` | Containerfile + Makefile `-e` | Explicit OpenCode config path     |

---

## Do / Do Not

**Do:**
- Keep scripts minimal and single-purpose; delegate logic to `make`.
- Run `make build` after any change to the `Containerfile` to verify it builds.
- Use `:Z` on SELinux-aware systems for all Podman bind mounts.
- Create `~/.opencode/config` and `~/.opencode/data` on the host before mounting.

**Do not:**
- Add application source code, compiled languages, or a package manager (npm/pip/cargo)
  to this repository — it is purely infrastructure.
- Commit `bun.lock` or the generated `.opencode/package.json`; they are git-ignored.
- Use `sudo` or run Podman as root — rootless is a hard requirement.
- Cache secrets or API keys in the `Containerfile` or Makefile.
- Skip `set -euo pipefail` in new Bash scripts without explicit justification.
