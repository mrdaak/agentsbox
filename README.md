# OpenCode with Podman

Run [OpenCode](https://opencode.ai/) in a containerized environment with project-specific workspaces and dev tooling pre-installed. Built from `nixos/nix:latest` with OpenCode installed via bun.

## Prerequisites

- [Nix](https://nixos.org/download/) (with flakes enabled)
- [Podman](https://podman.io/) (provided by the Nix flake)
- [direnv](https://direnv.net/) (optional, for auto-activation)

## Quick Start

```bash
# Enter the Nix dev shell (or let direnv do it automatically)
nix develop          # or: direnv allow (once)

# Use OpenCode from any project directory
cd ~/src/my-project
opencode            # Start interactive session
```

## Commands

Once inside the Nix dev shell, these commands are available from any directory:

| Command           | Description                                |
|-------------------|--------------------------------------------|
| `opencode`        | Run OpenCode in current directory          |
| `opencode-update` | Rebuild the container image (no cache)     |

## Manual Usage

Without the Nix shell functions:

```bash
# Build the custom image
make build

# Force rebuild without cache
make update

# Run OpenCode in a specific directory with arguments
make run WORKDIR=~/src/my-project
```

## Makefile Targets

| Target   | Description                                        |
| -------- | -------------------------------------------------- |
| `build`  | Build the container image from nixos/nix:latest    |
| `update` | Rebuild without cache                            |
| `run`    | Run OpenCode (requires WORKDIR, supports ARGS)     |

## Volume Mounts

Each invocation mounts:

| Host path                    | Container path                     | Mode |
| ---------------------------- | ---------------------------------- | ---- |
| `$(WORKDIR)`                 | `/workspace`                       | rw   |
| `~/.opencode/config`         | `/root/.config/opencode`           | rw   |
| `~/.opencode/data`           | `/root/.local/share/opencode`      | rw   |

**Note:** Environment variables `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, and `OPENCODE_CONFIG_DIR` are set automatically to ensure OpenCode loads your configuration correctly.

## Pre-installed Tools

The container includes:

- **Core**: curl, git, bash, make, ca-certificates, gnutar
- **Runtime**: bun, node
- **Search**: ripgrep, fd
- **Parsing**: jq
- **Display**: tree, less, ncurses

## Security

- **Rootless Podman** -- container root maps to your unprivileged host UID
- **Ephemeral** (`--rm`) -- containers are destroyed after each session
- **CWD-only** -- the agent can only see the directory you run it in
- **`no-new-privileges`** -- prevents privilege escalation inside the container
