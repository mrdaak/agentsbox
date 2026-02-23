# OpenCode with Podman

Run [OpenCode](https://opencode.ai/) in a containerized environment with project-specific workspaces and dev tooling pre-installed.

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
| `opencode-update` | Pull the latest upstream image and rebuild |

## Manual Usage

Without the Nix shell functions:

```bash
# Build the custom image
make build

# Update to latest upstream image
make update

# Run OpenCode in a specific directory with arguments
make run WORKDIR=~/src/my-project
```

## Makefile Targets

| Target   | Description                                        |
| -------- | -------------------------------------------------- |
| `build`  | Build the custom container image                   |
| `update` | Pull latest upstream image and rebuild (no cache)  |
| `run`    | Run OpenCode (requires WORKDIR, supports ARGS)     |

## Volume Mounts

Each invocation mounts:

| Host path                    | Container path                     | Mode |
| ---------------------------- | ---------------------------------- | ---- |
| `$(WORKDIR)`                 | `/workspace`                       | rw   |
| `~/.opencode/config`         | `/root/.config/opencode`           | rw   |
| `~/.opencode/data`           | `/root/.local/share/opencode`      | rw   |

## Pre-installed Tools

The container includes:

- **Core**: curl, git, bash, make, ca-certificates
- **Search**: ripgrep, fd
- **Parsing**: jq
- **Display**: tree, less, ncurses
- **Node.js**: nodejs, npm, yarn

## Security

- **Rootless Podman** -- container root maps to your unprivileged host UID
- **Ephemeral** (`--rm`) -- containers are destroyed after each session
- **CWD-only** -- the agent can only see the directory you run it in
- **`no-new-privileges`** -- prevents privilege escalation inside the container
