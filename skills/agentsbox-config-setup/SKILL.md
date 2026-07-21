---
name: agentsbox-config-setup
description: Use when the user wants to set up, configure, or review `.agentsbox/config.toml` for a project — e.g. "set my default agent to claude", "add a published port for my dev server", "persist my cargo/pip/go cache across `agentsbox enter` runs", "configure agentsbox for this repo", or any time they want to extend the project config without clobbering existing keys. Inspects the project to propose `[[ports]]` and `[[volumes]]` and writes valid TOML directly (the `agentsbox` CLI isn't available in-box).
---

# Set up `.agentsbox/config.toml` for a project

Guide the user interactively through creating/extending the project config at
`/workspace/.agentsbox/config.toml`, then write valid TOML. Inspect the project
to propose `[[ports]]` (dev/preview servers) and `[[volumes]]` (tool caches);
confirm each proposal with the user before writing.

## Runtime constraints (shape every step)

- This skill runs **inside** a project sandbox. The `agentsbox` CLI and `nu`
  are **not** on PATH here (only the agent binaries + devtools baked into the
  image are). Edit the TOML **directly** with your file tools (read/edit/write);
  do not shell out to `agentsbox config` (it can't add `[[volumes]]`/`[[ports]]`
  anyway) and do not parse/emit TOML via `nu -c`.
- **Parsed, never sourced:** config is read by nushell at `enter` time, never
  executed. Emit valid TOML only — a cloned repo must not run code, and invalid
  TOML fails the parse. No embedded scripts/commands.
- Target path is always `/workspace/.agentsbox/config.toml`.
- Keep the file **portable and committable**: in-container paths only (targets
  under `/root/` or built-in volume roots), no host-specific absolute paths.
  Note: `.agentsbox/` is gitignored in this repo's `.gitignore`; check your
  project's own `.gitignore` (add an entry if needed) and `git add -f
  .agentsbox/config.toml` if the team should share it.

## Config surface (what you may write)

Enforce these rules so `enter` doesn't reject the file. All rules come from
`bin/agentsbox` and `make.nu`.

| Key | Type | Valid values | Notes |
|-----|------|-------------|-------|
| `agent` | string | `claude`, `codex`, `opencode`, `pi`, `none` | `none` = plain shell. Precedence: `--agent` flag > project config > global config. The agent must also be in global `installed_agents` to actually launch. An absent `installed_agents` key bakes **all four** agents (the build default), so most users already have it — only warn in step 8 if the user has narrowed the set. |
| `AGENT_NAME` | string | bare alias (default: dir basename) | **Uppercase key.** A2A alias; nushell reads it case-sensitively. Optional/advanced; usually leave unset. |
| `network` | string | podman `--network` spec (`host`, `container:<name>`, named net) | **Leave unset by default.** `host`/`container:` disable `[[ports]]` publishing. **Any** non-empty `network` is incompatible with `--a2a` (`make.nu` aborts; `--a2a` sets its own `agentsbox-net`), so don't set it manually. |
| `[[volumes]]` | array of tables | `name` matches `^[A-Za-z0-9_.-]+$`; `target` absolute, not a built-in mount | Created lazily as `agent-<hash>-<name>`, mounted with `:Z`. |
| `[[ports]]` | array of tables | `host` int, `container` int, `bind` optional (default `127.0.0.1`; `0.0.0.0` → LAN) | Project-only. Skipped under `network = "host"`/`container:`. |

`[[volumes]]` `target` must **not** collide with a built-in mount (hard error
in `make.nu`). The built-in list:

```
/workspace /nix /pnpm-store
/root/.agents /root/.claude /root/.claude.json
/root/.codex /root/.config/codex /root/.local/share/codex
/root/.pi/agent /root/.config/opencode /root/.local/share/opencode
```

(`/pnpm-store` is already a built-in volume — never propose a pnpm-cache volume.)

### `installed_agents` — never write here

`installed_agents` is **global-only** (`~/.config/agentsbox.toml`), baked into
the image at build time, and changing it needs a rebuild. This skill only tells
the user the host-side command (step 8); it does not write the key.

## Setup flow

Each step has a completion criterion. Confirm proposals with the user before
writing.

1. **Locate & guard.**
   - Target: `/workspace/.agentsbox/config.toml`.
   - If it exists → **review mode**: read it, show the user what's set, offer to
     extend. Never overwrite; preserve all existing keys.
   - If `/workspace` has no manifest files and no git, still proceed — skip
     detection-driven proposals (steps 4–5) and just ask.
   - **Completion:** the existing file (if any) is read and its keys known
     before any write.

2. **Default agent.**
   - Ask whether an agent should auto-launch on `enter`, and which:
     `claude` / `codex` / `opencode` / `pi` / `none` (plain shell).
   - Constrain to the valid set; reject anything else.
   - Warn the picked agent must be in global `installed_agents` (host-side
     rebuild) to launch; `none` is always safe.
   - **Completion:** `agent` is set to a valid value or deliberately omitted.

3. **Inspect the project** (read-only; feeds steps 4–5).
   - Manifests: `package.json` (+ lockfiles), `go.mod`, `Cargo.toml`,
     `pyproject.toml`/`requirements.txt`, `Gemfile`, `composer.json`,
     `pom.xml`/`build.gradle`, `flake.nix`, `Makefile`/`justfile`,
     `Dockerfile`/`compose.y(a)ml`, `README.md`.
   - **Completion:** runtime(s) and any dev/preview server command + port
     candidate identified, or confirmed absent.

4. **Propose `[[ports]]`.**
   - For a detected dev/preview server, propose an entry. The **container**
     port is the port the server binds inside the box; **host** port defaults
     to the same. If the host port collides with another `[[ports]]` entry or a
     `--web` host port (18082, 28082, … — `<index>8082`), suggest shifting.
     Avoid `container = 8082`: that's the in-container Zellij web port and
     would clash with `--web`.
   - An explicit `--port <n>` / `-p <n>` / `PORT=<n>` in the script **overrides**
     the framework default — parse it.
   - `bind`: default `127.0.0.1` (host-only). Offer `0.0.0.0` only if the user
     wants LAN/tailnet reachability.
   - If nothing is detectable → **ask** the user for a port; don't invent one.
   - Note: ports are ignored under `network = "host"`/`container:`.
   - **Completion:** zero or more valid `[[ports]]` entries agreed, each with
     integer `host`+`container` and optional `bind`.

5. **Propose `[[volumes]]`.**
   - Detect tool caches that benefit from persistence across `enter` runs (see
     the volume table below). pnpm is already built-in — skip it.
   - Validate each proposal: `name` matches `^[A-Za-z0-9_.-]+$`, `target` is
     absolute, and `target` is not in the built-in list above. If a candidate
     collides, drop it and tell the user.
   - Confirm each volume with the user before writing (volumes persist data,
     namespaced per project — the user should opt in).
   - **Completion:** zero or more valid `[[volumes]]` entries agreed, each with
     a valid `name`+`target` and no built-in collision.

6. **Network / A2A (advanced, optional).**
   - Do **not** set `network` by default. If the user asks about joining another
     container's netns or host networking, explain: `host`/`container:` disable
     `[[ports]]` publishing, and **any** non-empty `network` breaks `--a2a`
     (which sets its own `agentsbox-net`).
   - If `.agentsbox/listen` exists, mention it (an A2A server `enter` offers to
     serve interactively) — but do not enable A2A from config; it stays a CLI
     choice.
   - **Completion:** `network` left unset unless the user explicitly asked,
     with incompatibilities explained.

7. **Write / merge the TOML.**
   - Merge into the existing file (if any), **preserving all other keys**.
   - Emit valid TOML only. `[[ports]]`/`[[volumes]]` are array-of-tables; each
     entry is its own `[[…]]` block. `host`/`container` are bare integers, not
     strings. `AGENT_NAME` is an uppercase bare key.
   - Show the user the final file and a one-line summary per section.
   - **Completion:** `.agentsbox/config.toml` is valid TOML, contains exactly
     the agreed keys, and existing unrelated keys are intact.

8. **Host-side reminder.**
   - If `agent` was set to something not known to be installed, print the
     host-side command to bake it in and rebuild. The skill can't run these (no
     `agentsbox` in-box; `installed_agents` is global):
     ```
     agentsbox config installed_agents <claude,codex,...> --global
     agentsbox update
     ```
   - **Completion:** the user is told what (if anything) must happen on the host
     for the config to take full effect.

## Port detection heuristics

Framework/script → default container port (override if the script sets an
explicit `--port`/`-p`/`PORT=`):

| Signal | Default port |
|--------|-------------|
| vite / svelte-kit | 5173 |
| next / nuxt / remix / create-react-app | 3000 |
| astro | 4321 |
| webpack-dev-server | 8080 |
| parcel | 1234 |
| expo | 8081 |
| Django `manage.py runserver` | 8000 |
| rails s | 3000 |
| flask | 5000 |
| fastapi / uvicorn | 8000 |
| go net/http with a literal `:PORT` | that port |
| `compose.yaml` `ports:` | confirm with user (host mappings, not this box) |

If nothing matches: ask; never invent a port.

## Volume detection heuristics

Manifest → cache target(s). Skip pnpm (built-in `/pnpm-store`). Always validate
the target against the built-in list above.

| Manifest | name | target |
|-----------|------|--------|
| `go.mod` | `go-cache` | `/root/go` |
| `go.mod` (optional) | `go-build-cache` | `/root/.cache/go-build` |
| `Cargo.toml` | `cargo-registry` | `/root/.cargo/registry` |
| `Cargo.toml` (optional) | `cargo-git` | `/root/.cargo/git` |
| `pyproject.toml`/`requirements.txt` | `pip-cache` | `/root/.cache/pip` |
| `Gemfile` | `bundle-cache` | `/root/.bundle` |
| `composer.json` | `composer-cache` | `/root/.composer/cache` |
| `pom.xml` | `maven-cache` | `/root/.m2` |
| `build.gradle` | `gradle-cache` | `/root/.gradle` |
| npm (`package-lock.json`/no pnpm lock) | `npm-cache` | `/root/.npm` |
| `bun.lock`/`bun.lockb` | `bun-cache` | `/root/.bun/install/cache` |
| `yarn.lock` | `yarn-cache` | `/root/.cache/yarn` |

A project venv (e.g. `/root/.venv`) only if the user asks to persist one.

## Invariants

- **Parsed, never sourced** → valid TOML only; no scripts/commands in the file.
- **No `agentsbox`/`nu` in-box** → edit the file directly; don't shell out.
- `agent` valid set: `claude codex opencode pi none`.
- `[[volumes]]` `name` regex `^[A-Za-z0-9_.-]+$`; `target` absolute; no built-in
  collision.
- `[[ports]]` `host`+`container` are **integers**; `bind` defaults
  `127.0.0.1`; `0.0.0.0` → LAN; project-only; skipped under
  `network = "host"`/`container:`.
- `installed_agents` is global-only + rebuild-gated → never write it here.
- `AGENT_NAME` is an **uppercase** bare key.
- Portable: no host paths; `git add -f` if sharing with the team.
