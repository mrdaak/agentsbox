---
name: agentsbox-guide
description: Use when the user asks about agentsbox itself — how the sandbox works, its commands, configuration, secrets/volumes/ports, A2A, --web, the security model, or how to create and build custom agentsbox workflow images. Points to the agentsbox documentation baked into this box.
---

# agentsbox guide

agentsbox runs each project's coding agent in a rootless, ephemeral Podman
container. Its documentation is baked into this image:

- `/opt/agentsbox/README.md` — how it works: `enter`, the command surface,
  project and global config, secrets, persistent volumes, published ports, A2A,
  `--web`, and the security model.
- `/opt/agentsbox/docs/custom-agents.md` — creating a custom workflow image: the
  profile layout (`image.toml` plus an executable `run`), `agentsbox image build`
  and `agentsbox image run`, the read-only `/workspace` and writable `/reports`
  mount contract.

Read the relevant file before answering. Do not guess at commands or config
keys.

## In-box constraints

- The `agentsbox` CLI and `nu` are **not** on PATH inside this box. You cannot
  run `agentsbox enter`, `agentsbox image build`, or `agentsbox image run` here.
- Podman cannot run inside this container. You can author a workflow profile
  (`image.toml`, `run`, optional `rules.nix`, `files`) and check its contents,
  but you cannot build or run the image. Produce the profile and give the user
  the host command to run.
- These docs are frozen at image build time. They describe this image's version,
  which may differ from a newer checkout elsewhere.

For writing a project's `.agentsbox/config.toml`, use the
`agentsbox-config-setup` skill; for a project flake, use
`agentsbox-scaffold-minimal-flake`.
