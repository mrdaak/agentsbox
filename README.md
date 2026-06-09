# AI Agents with Podman

Run AI coding agents (Claude Code, OpenCode, Codex) in a containerized environment with project-specific workspaces and dev tooling pre-installed. Built from `ghcr.io/nixos/nix:2.34.7` with all tools installed via Nix.

## Prerequisites

- [Nix](https://nixos.org/download/) with flakes enabled
- A working Podman setup (rootless on Linux, `podman machine` on macOS). `podman` itself is bundled into the installed package, but the host-side service/VM is yours to manage.

## Install

```bash
# Install from a local clone
nix profile install /path/to/this/repo

# ...or directly from a flake reference (once published)
# nix profile install github:<org>/<repo>
```

This puts `agents` on your `PATH`. Run it from any project directory — that directory is mounted into the container.

```bash
cd ~/src/my-project
agents enter        # enter an agent shell in this directory
agents list         # list running agent containers
agents doctor       # check host environment
agents update       # pull a fresh base image and rebuild
```

Pick up flake changes with `nix profile upgrade agents`. Uninstall with `nix profile remove agents`.

## Commands

| Command          | Description                                                |
| ---------------- | ---------------------------------------------------------- |
| `agents enter`   | Enter an agent shell in the current directory              |
| `agents list`    | List running agent containers (pass `-a` for stopped too)  |
| `agents load-secret <file>` | Load a file as a podman secret, mounted into a project's agent shell |
| `agents update`  | Pull the latest base image and rebuild the container       |
| `agents doctor`  | Check host environment for required tooling                |
| `agents help`    | Show usage                                                 |

Running `agents` with no subcommand prints usage. `agents enter` (alias: `agents run`) accepts `--auth` to bind host port `1455:1455` for OpenCode auth flows.

## Development

To hack on this tool itself, use the dev shell instead of (or alongside) a profile install:

```bash
nix develop          # or: direnv allow (once)
make run WORKDIR=~/src/my-project
```

The dev shell adds `bin/` to `PATH` so the same `agents` command resolves against the working tree rather than the Nix store.

### Makefile Targets

| Target             | Description                                                  |
| ------------------ | ------------------------------------------------------------ |
| `build`            | Build the container image                                    |
| `update`           | Rebuild without cache                                        |
| `run`              | Run the agent (requires `WORKDIR`)                           |
| `doctor`           | Run `bin/doctor`                                             |
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

## Per-project Secrets

For credentials a project needs — a private-registry `.npmrc`, a `.env`, a deploy token,
cloud creds — use `agents load-secret`. It stores the file as a podman secret scoped to that
project and mounts it (read-only) only into that project's agent shell.

```bash
cd ~/src/my-project
agents load-secret ~/.npmrc --target /root/.npmrc   # private registry tokens
agents load-secret ./.env                           # mounts at /root/.env
agents load-secret ./gh-token --target /root/.config/gh/hosts.yml
agents load-secret ~/secrets/key --project ~/src/other
```

Options: `--target PATH` sets the in-container mount path (default `/root/<filename>`);
`--name NAME` sets the secret key (default the filename); `--project DIR` picks the project
(default the current directory). Re-loading the same name replaces it, so that's also how you
rotate.

Under the hood each secret is a podman secret named `agent-<project-hash>-<name>` with the
mount target stored in a label; `agents enter` mounts every secret matching the current
project's hash. Inspect or remove them with plain podman:

```bash
podman secret ls
podman secret rm agent-<hash>-<name>
```

> Note: these are stored by podman's local (unencrypted) secret driver and mounted as
> root-readable files inside the container. Fine for local dev credentials; don't treat it
> as a vault.

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
