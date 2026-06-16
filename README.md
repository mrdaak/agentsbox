%title: agentsbox - Agent sandbox shell

agentsbox
==================

Run your favourite AI coding agents (Claude Code, OpenCode, Codex, Pi) in a secure environment isolated from your host OS.

```bash
cd project1
agentsbox enter
```

...and you are in a secure shell access-limited to the project(1). (green border = sandbox)

now you can run and configure any of the named agents. But If you already have one configured on your host OS,
sandbox will automatically pickup the configuration and you can continue from where you left of.

Agents state persists across runs! Skills, MCPs - all there!

But of what use is an agent kept in the dark?! Every once in a while you might want agent to have access to a secret from host OS.
For example NPM token. We can do that:

```bash
# while in project1 dir
agentsbox secrets add ~/.npmrc
```

...and project(1) now has `.npmrc` access in the sandbox.

---

## Install

- [Nix](https://nixos.org/download/) with flakes enabled

```bash
nix profile install github:mrdakdev/agentsbox
```

This puts `agentsbox` on your `PATH`. Run it from any project directory — that directory is mounted into the container.

## Commands

| Command                        | Description                                                                       |
| ------------------------------ | --------------------------------------------------------------------------------- |
| `agentsbox enter`              | Enter an agent shell in the current directory                                     |
| `agentsbox ls`                 | List running agent containers (pass `-a` for stopped too)                         |
| `agentsbox secrets add <file>` | Load a file as a podman secret, mounted into a project's agent shell              |
| `agentsbox secrets ls`         | List the secrets mounted into a project's agent shell                             |
| `agentsbox install-skills`     | Install agentsbox's bundled skills into `~/.agents/skills` (symlinked for Claude) |
| `agentsbox update`             | Pull the latest base image and rebuild the container                              |
| `agentsbox doctor`             | Check host environment for required tooling                                       |
| `agentsbox help`               | Show usage                                                                        |

`agentsbox enter --a2a` (enable [agent-to-agent messaging](#agent-to-agent-messaging-a2a)).

`agentsbox enter --web` serves [Zellij's web client](https://zellij.dev/documentation/web-client.html). It listens on `127.0.0.1:8082` in the container; on the host it's published to `<index>8082`, where the index is the agent's slot in `agentsbox ls` (agent 1 → `18082`, agent 2 → `28082`, …), so multiple agents never collide. A one-time login token prints on enter — copy it then, as it can't be retrieved later.

---

## Secrets

For credentials a project needs — a private-registry `.npmrc`, a `.env`, a deploy token,
cloud creds — use `agentsbox secrets add`. It stores the file as a podman secret and mounts it
(read-only) into the agent shell. By default a secret is scoped to **one project** and mounts
only into that project's shell; `--global` mounts it into **every** project's shell.

```bash
cd ~/src/my-project
agentsbox secrets add ./.env                           # this project, mounts at /root/.env
agentsbox secrets add ./gh-token --target /root/.config/gh/hosts.yml
agentsbox secrets add ~/secrets/key --project ~/src/other
agentsbox secrets add ~/.npmrc --target /root/.npmrc --global   # all projects
```

If a project secret and a global one share a target, the project one wins.
Inspect or remove them with plain podman:

```bash
podman secret ls
podman secret rm agent-<hash>-<name>
```

---

## Automatic project setup with Nix

If your project has `flake.nix`, on `enter` the sandbox spots it and offers
to load so you get the exact/reproducible developer toolchain (no "works on my machine"):

```bash
Detected flake.nix. Load nix environment? [Y/n]:
```

---

## Work on two features at once

Use **git worktrees** and hack on parallel features side by side, each on its own branch:

```bash
# inside the sandbox
git worktree add ../wt1            # new branch + dir at /wt1
```

Done? `git merge wt1` and `git worktree remove wt1`.

---

## Agent-to-agent messaging (A2A)

An agent working in one project can ask the agent in another project a question.
This is a minimal subset of the [A2A protocol](https://a2a-protocol.org/) —
JSON-RPC 2.0 `message/send` over HTTP — wired between containers.

Start each project's shell with `--a2a`:

```bash
# terminal A
cd ~/src/repo2 && agentsbox enter --a2a      # listens as "repo2"

# terminal B
cd ~/src/repo1 && agentsbox enter --a2a
```

The A2A listener answers incoming messages by running a headless agent over the
container's `/workspace`. It defaults to Claude Code (`claude -p`); pass an agent
to `--a2a` to choose. Codex runs through the in-container wrapper that handles
the nested-sandbox flags for `codex exec`:

```bash
cd ~/src/repo1 && agentsbox enter --a2a codex
```

---

## Security

- **Containers**
  - **lightweight**
  - **isolated**: vulnerability in 1 container is isolated from other parts
  - **short-lived**: frequently rebuilt from version-controlled sources
- **Ephemeral** (`--rm`) — containers are destroyed after each session
> Ephemeral means that the container can be stopped and destroyed,
> then rebuilt and replaced with an absolute minimum set up and configuration.
[Docker best practices](https://docs.docker.com/build/building/best-practices/#create-ephemeral-containers)
- **Workspace-only** — the agent sees `/workspace` plus the explicitly-listed config mounts, nothing else
- **no-new-privileges** — flag prevents privilege escalation inside the container
