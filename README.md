# Agent sandbox

Run your favourite AI coding agents (Claude Code, OpenCode, Codex, Pi) in a secure environment isolated from your host OS.

``` bash
cd project1
agentsbox enter
```

...and you are in a secure shell access-limited to the project(1). (green border = sandbox)

now you can run and configure any of the named agents. But If you already have one configured on your host OS,
sandbox will automatically pickup the configuration and you can continue from where you left of.

Agents state persists across runs! Skills, MCPs - all there!

But of what use is an agent kept in the dark?! Every once in a while you might want agent to have access to a secret from host OS.
For example NPM token. We can do that:

``` bash
# while in project1 dir
agentsbox load-secret ~/.npmrc
```

...and project(1) now has `.npmrc` access in the sandbox.

## Install

- [Nix](https://nixos.org/download/) with flakes enabled

```bash
nix profile install github:mrdakdev/agentsbox
```

This puts `agentsbox` on your `PATH`. Run it from any project directory — that directory is mounted into the container.

## Commands

| Command          | Description                                                |
| ---------------- | ---------------------------------------------------------- |
| `agentsbox enter`   | Enter an agent shell in the current directory              |
| `agentsbox list`    | List running agent containers (pass `-a` for stopped too)  |
| `agentsbox load-secret <file>` | Load a file as a podman secret, mounted into a project's agent shell |
| `agentsbox update`  | Pull the latest base image and rebuild the container       |
| `agentsbox doctor`  | Check host environment for required tooling                |
| `agentsbox help`    | Show usage                                                 |

## Volume Mounts

Each invocation mounts:

| Host path                       | Container path                       |
| ------------------------------- | ------------------------------------ |
| `$(WORKDIR)`                    | `/workspace`                         |
| bundled Zellij config           | `/root/.config/zellij/config.kdl`    |
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

## Persistent Stores

Two named volumes survive across container runs and are shared by all projects:

- **`agent-nix-store`** — the `/nix` store so packages don't re-download on every run.
- **`agent-pnpm-store`** — the pnpm content-addressable store at `/pnpm-store`. Configured via `/root/.config/pnpm/config.yaml` (`storeDir`, `packageImportMethod: copy`). Copy mode avoids cross-filesystem hardlink issues between the volume and the bind-mounted `/workspace`.

Use `make clean-nix-store` / `make clean-pnpm-store` to wipe them.

## Secrets

For credentials a project needs — a private-registry `.npmrc`, a `.env`, a deploy token,
cloud creds — use `agentsbox load-secret`. It stores the file as a podman secret and mounts it
(read-only) into the agent shell. By default a secret is scoped to **one project** and mounts
only into that project's shell; `--global` mounts it into **every** project's shell.

```bash
cd ~/src/my-project
agentsbox load-secret ./.env                           # this project, mounts at /root/.env
agentsbox load-secret ./gh-token --target /root/.config/gh/hosts.yml
agentsbox load-secret ~/secrets/key --project ~/src/other
agentsbox load-secret ~/.npmrc --target /root/.npmrc --global   # all projects
```

Options: `--target PATH` sets the in-container mount path (default `/root/<filename>`);
`--name NAME` sets the secret key (default the filename); `--project DIR` picks the project
(default the current directory); `--global` scopes it to all projects (mutually exclusive with
`--project`). Re-loading the same name replaces it, so that's also how you rotate.

If a project secret and a global one share a target, the project one wins.
Inspect or remove them with plain podman:

```bash
podman secret ls
podman secret rm agent-<hash>-<name>
```

## Security

- **Rootless Podman** — container root maps to your unprivileged host UID
- **Ephemeral** (`--rm`) — containers are destroyed after each session
- **Workspace-only** — the agent only sees the directory you mounted
- **`no-new-privileges`** — prevents privilege escalation inside the container
