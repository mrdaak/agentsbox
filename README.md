# OpenCode AI Tools

Run OpenCode in a containerized environment with project-specific workspaces.

## Quick Start

```bash
make
```

This enters a Nix shell with the `opencode` available.

## Commands

Inside the Nix shell:

### OpenCode
- `opencode` - Run OpenCode in current directory
- `opencode-update` - Pull latest base image

## Manual Usage

Without Nix shell:

```bash
# OpenCode
make run WORKDIR=~/src/my-project
```
