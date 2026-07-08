agentsbox
==================

Run your favourite AI coding agents — Claude Code, OpenCode, Codex, Pi — in a rootless, ephemeral sandbox isolated from your host OS.

It's for developers who want that power without letting an agent touch the host filesystem, run commands as your user, or read credentials it doesn't need. Each project's agent runs in its own Podman container, pre-configured so your agent config, skills, and MCPs just work.

```bash
agentsbox enter
```

Opens the current directory in a sandboxed agent shell — the green border means you're isolated. On first run, a one-time checklist picks which agents to bake into the image (saved globally, never asked again).

Isolated doesn't mean limited. agentsbox hands agents the [secrets](#secrets) they need, lets them collaborate across projects over [A2A](#agent-to-agent-messaging-a2a), and [sets up projects automatically with Nix](#automatic-project-setup-with-nix) — and you can drive any session from your [browser](#use-it-from-your-browser).

---

## Prerequisites

- **[Nix](https://nixos.org/download/)** package manager — used to install agentsbox and to provision the in-container toolchain.
- **[Podman](https://podman.io/getting-started/installation)** — the container engine. Must be installed and running (rootless; no daemon-as-root needed).
- **OS:** Linux and macOS. (On macOS, Podman runs in a lightweight VM — `agentsbox doctor` will tell you if the machine isn't ready.) Windows is not currently supported; use WSL2 + Linux Podman.

## Install

```bash
nix profile install github:mrdaak/agentsbox
```

Now you can run `agentsbox` from any project directory. If anything goes wrong, start with `agentsbox doctor`.

## Upgrade

Update the `agentsbox` command to the latest published version:

```bash
nix profile upgrade agentsbox
```

## Commands

| Command                        | Description                                                                       |
| ------------------------------ | --------------------------------------------------------------------------------- |
| `agentsbox enter`              | Enter an agent shell in the current directory                                     |
| `agentsbox ls`                 | List running agent containers (pass `-a` for stopped too)                         |
| `agentsbox secrets add <file>` | Load a file as a podman secret, mounted into a project's agent shell              |
| `agentsbox secrets ls`         | List the secrets mounted into a project's agent shell                             |
| `agentsbox secrets rm <name>`  | Remove a secret from a project's agent shell                                      |
| `agentsbox install-skills`     | Install agentsbox's bundled skills into `~/.agents/skills` (symlinked for Claude) |
| `agentsbox config`             | Set a config value (e.g. default `agent`) in `.agentsbox/config.toml`             |
| `agentsbox update`             | Pull the latest base image and rebuild the container                              |
| `agentsbox doctor`             | Check host environment for required tooling                                       |
| `agentsbox help`               | Show usage                                                                        |

`agentsbox enter --a2a` (enable [agent-to-agent messaging](#agent-to-agent-messaging-a2a)).

`agentsbox enter --web` (drive your session from a [browser](#use-it-from-your-browser)).

## Installed agents

Four agents can be baked in: Claude Code, OpenAI Codex, Pi, OpenCode. You
choose which on first run — pick only what you use to keep the image small.
The selection is **global** (host-level, not per-project) in
`~/.config/agentsbox.toml`:

```toml
# ~/.config/agentsbox.toml
installed_agents = ["claude"]
```

- On first `enter` (TTY, no key, no image yet) you get a one-time checklist;
  the choice is saved so it never asks again. CI / non-interactive runs skip
  it and build all four.
- Set manually: `agentsbox config installed_agents claude,codex --global`.

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

Remove a secret by the same name and scope you added it with:

```bash
agentsbox secrets rm .env                       # this project's .env secret
agentsbox secrets rm key --project ~/src/other  # another project's secret
agentsbox secrets rm .npmrc --global            # the global secret
```

---

## Persistent volumes

Toolchains or caches that should survive across runs (a Go install dir, an npm
cache, …) can be declared as named volumes in `.agentsbox/config.toml`:

```toml
[[volumes]]
name   = "go-cache"
target = "/root/go"
```

On `enter`, each volume is created if missing (namespaced so projects don't
collide) and mounted at `target`. The config is parsed, never sourced — a
cloned repo can't run code at `enter` time.

---

## Automatic project setup with Nix

If your project has `flake.nix`, on `enter` the sandbox spots it and offers
to load so you get the exact/reproducible developer toolchain (no "works on my machine"):

```bash
Detected flake.nix. Load nix environment? [Y/n]:
```

---

## Agent-to-agent messaging (A2A)

An agent working in one project can ask the agent in another project a question.

Start each project's shell with `--a2a`:

```bash
# folder "backend"
agentsbox enter --a2a      # listens as "backend"

# folder "frontend"
agentsbox enter --a2a      # listens as "frontend"
```

Each agent stays focused on its own project — the frontend agent keeps a clean, frontend-only
context, and when it needs a backend API it just asks the backend agent instead of reaching into
files it shouldn't see. You get a specialist per project, not one agent juggling everything.

Each box's A2A alias defaults to its **project directory basename** (`backend/` → `backend`); override it with `agentsbox enter --a2a --agent-name <name>`.

---

## Use it from your browser

`agentsbox enter --web` serves your session over HTTP — drive the agent from any browser.

---

## Security

agentsbox runs each agent **rootless** (never as root on your host) in an ephemeral Podman container:

- **Rootless** — Podman runs as your user; there is no root daemon and the container has no path to host root.
- **Workspace-only filesystem** — the agent sees `/workspace` (your project) plus the explicitly-listed config/skill mounts, nothing else on your host.
- **`no-new-privileges`** — `--security-opt no-new-privileges:true` blocks any privilege escalation inside the container.
- **Ephemeral (`--rm`)** — containers are destroyed after each session, so nothing persists between runs unless you mount it. ([Docker best practices](https://docs.docker.com/build/building/best-practices/#create-ephemeral-containers))
- **Reproducible base** — the image is built from a pinned `ghcr.io/nixos/nix` base and a version-pinned Nix profile, rebuilt from version-controlled sources.

Secrets are delivered as Podman secrets (read-only), never env vars, so they never appear in `inspect`/logs.

---

## Extras: right-click "Open in agentsbox" (macOS)

In **Automator.app** create a new **Quick Action** that receives **folders** in **Finder**, add a **Run Shell Script** step set to **Pass input → as arguments**, and fill in the body with:

```bash
for DIR in "$@"; do
  [ -n "$DIR" ] || continue
  open -a Terminal "$DIR"
  /usr/bin/osascript \
    -e 'delay 0.6' \
    -e 'tell application "Terminal"' \
    -e 'activate' \
    -e 'do script "agentsbox enter" in front window' \
    -e 'end tell'
done
```




Save it as "Open in agentsbox"; now right-click any folder → **Quick Actions** to open a Terminal there running `agentsbox enter`.
