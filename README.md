# AI Agents with Podman

Run AI coding agents (Claude Code, OpenCode, Codex) in a containerized environment with project-specific workspaces and dev tooling pre-installed. Built from `ghcr.io/nixos/nix:2.34.7` with all tools installed via Nix.

## Prerequisites

- [Nix](https://nixos.org/download/) (with flakes enabled)
- [Podman](https://podman.io/) (provided by the Nix flake)
- [direnv](https://direnv.net/) (optional, for auto-activation)

## Quick Start

```bash
# Enter the Nix dev shell (or let direnv do it automatically)
nix develop          # or: direnv allow (once)

# Run an agent in a project directory
make run WORKDIR=~/src/my-project
```

## Makefile Targets

| Target             | Description                                                  |
| ------------------ | ------------------------------------------------------------ |
| `build`            | Build the container image                                    |
| `update`           | Rebuild without cache                                        |
| `run`              | Run the agent (requires `WORKDIR`)                           |
| `clean-nix-store`  | Remove the persistent Nix store volume                       |
| `clean-pnpm-store` | Remove the persistent pnpm store volume                      |

## Run Flags

| Variable | Purpose                                                                 |
| -------- | ----------------------------------------------------------------------- |
| `WORKDIR` | Required. Host directory mounted at `/workspace`                       |
| `AUTH`    | If set, binds host port `1455:1455` for OpenCode auth flows            |

Container names are derived from `WORKDIR` (`agent-<basename>-<hash>`), so multiple projects can run side-by-side without collision.

## Volume Mounts

Each invocation mounts:

| Host path                       | Container path                       |
| ------------------------------- | ------------------------------------ |
| `$(WORKDIR)`                    | `/workspace`                         |
| `~/.agents`                     | `/root/.agents`                      |
| `~/.opencode/config`            | `/root/.config/opencode`             |
| `~/.opencode/data`              | `/root/.local/share/opencode`        |
| `~/.claude`                     | `/root/.claude`                      |
| `~/.claude.json`                | `/root/.claude.json`                 |
| `~/.codex`                      | `/root/.codex`                       |
| `~/.config/codex`               | `/root/.config/codex`                |
| `~/.local/share/codex`          | `/root/.local/share/codex`           |
| `agent-nix-store` (volume)      | `/nix`                               |
| `agent-pnpm-store` (volume)     | `/pnpm-store`                        |

`XDG_CONFIG_HOME`, `XDG_DATA_HOME`, and `OPENCODE_CONFIG_DIR` are set automatically so each agent picks up its config from the expected paths.

## Persistent Stores

Two named volumes survive across container runs and are shared by all projects:

- **`agent-nix-store`** — the `/nix` store so packages don't re-download on every run.
- **`agent-pnpm-store`** — the pnpm content-addressable store at `/pnpm-store`. Configured via `/root/.config/pnpm/config.yaml` (`storeDir`, `packageImportMethod: copy`). Copy mode avoids cross-filesystem hardlink issues between the volume and the bind-mounted `/workspace`.

Use `make clean-nix-store` / `make clean-pnpm-store` to wipe them.

## npmrc Secret (optional)

If a Podman secret named `npmrc` exists, it's mounted read-only at `/root/.npmrc`. Useful for private registry tokens without baking them into the image or committing them to project files.

```bash
podman secret create npmrc ~/.npmrc
# or from stdin:
printf '//npm.pkg.github.com/:_authToken=ghp_xxx\n' | podman secret create npmrc -
```

To rotate: `podman secret rm npmrc && podman secret create npmrc <source>`.

## Pre-installed Tools

Installed via Nix in the image:

- **Agents**: claude-code, opencode
- **Core**: bash, curl, git, gnumake, gnutar, gnused, unzip, ca-certificates
- **Runtime**: nodejs
- **Multiplexer**: zellij
- **Search**: ripgrep, fd
- **Parsing**: jq
- **Display**: tree, less, ncurses

## Security

- **Rootless Podman** — container root maps to your unprivileged host UID
- **Ephemeral** (`--rm`) — containers are destroyed after each session
- **Workspace-only** — the agent only sees the directory you mounted
- **`no-new-privileges`** — prevents privilege escalation inside the container
