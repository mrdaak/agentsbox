%title: agentsbox - Agent sandbox shell

agentsbox
==================

Run your favourite AI coding agents (Claude Code, OpenCode, Codex, Pi) in a secure environment isolated from your host OS.

Today's agents run commands, install packages, and act on web content autonomously — one bad instruction or compromised dependency shouldn't reach the rest of your machine.

```bash
agentsbox enter
```

Opens the current directory in a secure agent shell. Green border = sandboxed.

Supported agents come pre-installed — your existing config, skills, and MCPs carry over automatically.

But of what use is an agent kept in the dark? agentsbox can hand agents the [secrets](#secrets) they need, let them collaborate across projects over [A2A](#agent-to-agent-messaging-a2a), and [set up projects automatically with Nix](#automatic-project-setup-with-nix). You can even drive any session from your [browser](#use-it-from-your-browser).

---

## Install

- [Nix](https://nixos.org/download/) package manager

```bash
nix profile add github:mrdakdev/agentsbox
```

Now you can run `agentsbox` from any project directory.

## Commands

| Command                        | Description                                                                       |
| ------------------------------ | --------------------------------------------------------------------------------- |
| `agentsbox enter`              | Enter an agent shell in the current directory                                     |
| `agentsbox ls`                 | List running agent containers (pass `-a` for stopped too)                         |
| `agentsbox secrets add <file>` | Load a file as a podman secret, mounted into a project's agent shell              |
| `agentsbox secrets ls`         | List the secrets mounted into a project's agent shell                             |
| `agentsbox secrets rm <name>`  | Remove a secret from a project's agent shell                                      |
| `agentsbox install-skills`     | Install agentsbox's bundled skills into `~/.agents/skills` (symlinked for Claude) |
| `agentsbox update`             | Pull the latest base image and rebuild the container                              |
| `agentsbox doctor`             | Check host environment for required tooling                                       |
| `agentsbox help`               | Show usage                                                                        |

`agentsbox enter --a2a` (enable [agent-to-agent messaging](#agent-to-agent-messaging-a2a)).

`agentsbox enter --web` (drive your session from a [browser](#use-it-from-your-browser)).

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

---

## Use it from your browser

`agentsbox enter --web` serves your session over HTTP — drive the agent from any browser.

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




Save it as "Open in agentsbox"; now right-click any folder → **Quick Actions** to open a Terminal there running `agentsbox enter`
