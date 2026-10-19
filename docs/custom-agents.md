# Creating a custom agentsbox agent

A custom agent is a standalone OCI image. The image contains one selected
coding agent, its declared extra tools, basic runtime utilities,
and the files needed by its workflow.

## Define the job

Start with one clear outcome, such as a PR risk review, a CI workflow audit, or
a security report. Decide what the agent may read, whether it may execute target
code, and what artifacts it must produce. A narrow, report-only workflow is a
good first version.

## Create the profile

The directory needs an `image.toml` and an executable `run` script:

```toml
name = "repo-review"
agent = "codex"
tools = []
files = ["prompt.md"]
```

`image.toml` names the image, selects one of `claude`, `codex`, `pi`, or
`opencode`, lists packages from the centrally pinned nixpkgs set, and allowlists
the runtime files to copy. The `run` script is the image entrypoint: it invokes
the selected agent, handles workflow options, and writes results. Add prompts,
schemas, or other assets to `files` only when the workflow needs them. An
optional `rules.nix` can bundle data at build time using the same pinned `pkgs`
set. A profile-local `AGENTS.md` can guide development; it is not a runtime
instruction unless deliberately bundled and used by the workflow.

## Build and run

```bash
agentsbox image build ./repo-review
agentsbox image run repo-review:latest /path/to/target-repo
```

`image run` mounts the target read-only at `/workspace` and provides a writable
`/reports` directory outside the target. The image must create its own report
there; `image.toml` does not define the workflow by itself. For a Codex
workflow, `--codex-auth` explicitly mounts an existing login. Keep credentials
and repository-specific inputs out of the image. The image can also run with a
regular OCI runtime without the agentsbox CLI.

## Validate before reuse

Check the manifest and script syntax, build the image, and run it against a
small representative repository. Inspect the report, error handling, mounted
paths, and network behavior. Then try a larger repository before relying on it
in CI. Rebuild the image when its profile or bundled defaults change; runtime
options are handled by the workflow's `run` script.
