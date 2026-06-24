#!/usr/bin/env nu
# make.nu — task runner for agentsbox (build / run / update / shell / clean / doctor).
# Invoked by bin/agentsbox as `nu make.nu <subcommand> [flags]`; resolves the repo
# root via $env.AGENTS_TOOLS_DIR (set by flake.nix).

const IMAGE_NAME = "agentsbox"
const NIX_VOLUME = "agent-nix-store"
const PNPM_VOLUME = "agent-pnpm-store"

# Image tag: AGENTSBOX_VERSION (set by flake.nix), falling back to "latest" for a
# raw `nu make.nu` call. The versioned tag pins the running image to the installed
# agentsbox; build/update write both it and `latest` so a failed rebuild leaves the
# previous version's tag as a rollback target.
def image-tag [] {
    $env.AGENTSBOX_VERSION? | default "latest"
}

# Repo root — source of truth for the Containerfile and zellij-config.kdl.
def root [] {
    let r = ($env.AGENTS_TOOLS_DIR?)
    if ($r | is-empty) {
        error make {msg: "AGENTS_TOOLS_DIR is not set (provided by flake.nix)"}
    }
    $r
}

def build-log [] {
    $env.BUILD_LOG? | default "/tmp/agentsbox-build.log"
}

# SHA-1 of the workdir path, first 8 hex. nushell has no `hash sha1`, so shell out
# to sha1sum — and pipe WITHOUT a trailing newline, matching bin/agentsbox's sha1_8
# and bin/list-secrets. The container name and secret/volume prefixes depend on
# this lining up exactly; do not change without re-verifying all three.
def workdir-hash [workdir: string] {
    $workdir | ^sha1sum | split row " " | first | str substring 0..<8
}

# --secret flags for `podman run`. `podman secret ls` has no label filter, so match
# by name prefix: project secrets (agent-<hash>-) first, then globals
# (agent-global-). The mount target lives in the agents.target label. On a shared
# target the first wins (project beats global) — uniq-by keeps the first, and
# podman rejects two mounts at one path.
def secret-flags [hash: string] {
    let all = (do -i { podman secret ls --format '{{.Name}}' } | default "" | lines)
    let names = (
        ($all | where {|n| $n | str starts-with $"agent-($hash)-"})
        ++ ($all | where {|n| $n | str starts-with "agent-global-"})
    )
    $names
    | each {|n|
        let t = (
            do -i { podman secret inspect $n --format '{{index .Spec.Labels "agents.target"}}' }
            | default "" | str trim
        )
        {name: $n, target: $t}
    }
    | where target != ""
    | uniq-by target
    | each {|s| ["--secret" $"($s.name),target=($s.target),mode=0400"] }
    | flatten
}

# In-container paths already bound by built-in mounts (run_args) and secrets —
# a project-declared volume may not reuse one, since podman rejects two mounts
# at the same path and we want to fail with a clear message rather than podman's.
def built-in-mounts [] {
    [ /workspace /nix /pnpm-store
      /root/.agents /root/.claude /root/.claude.json
      /root/.codex /root/.config/codex /root/.local/share/codex
      /root/.pi/agent /root/.config/opencode /root/.local/share/opencode ]
}

# -v flags for project-declared [[volumes]] (each entry "name:target"). Namespaced
# agent-<hash>-<name> (like secrets) so projects can't collide, created lazily so a
# fresh checkout just works on first `enter`, mounted with :Z for SELinux. Name
# shape, absolute target, and collisions with built-in mounts are hard errors — a
# typo shouldn't silently drop a mount the user expects.
def volume-flags [hash: string, entries: list] {
    if ($entries | is-empty) { return [] }
    let existing = (do -i { podman volume ls --format '{{.Name}}' } | default "" | lines)
    let mounts = (built-in-mounts)
    $entries
    | each {|entry|
        let parts = ($entry | split row ":")
        if ($parts | length) != 2 {
            error make {msg: $"agentsbox: malformed volume '($entry)' (expected name:target)"}
        }
        let name = ($parts | first)
        let target = ($parts | last)
        if ($name | is-empty) {
            error make {msg: $"agentsbox: volume entry '($entry)' has an empty name"}
        }
        if not ($name =~ '^[A-Za-z0-9_.-]+$') {
            error make {msg: $"agentsbox: invalid volume name '($name)' (allowed: A-Z a-z 0-9 _ . -)"}
        }
        if ($target | is-empty) or not ($target | str starts-with "/") {
            error make {msg: $"agentsbox: volume target '($target)' must be an absolute path"}
        }
        if ($target in $mounts) {
            error make {msg: $"agentsbox: volume target '($target)' collides with a built-in mount"}
        }
        let effective = $"agent-($hash)-($name)"
        if ($effective not-in $existing) {
            podman volume create $effective out+err>| ignore
        }
        ["-v" $"($effective):($target):Z"]
    }
    | flatten
}

# Confirm podman is on PATH before reaching `podman build`, which would otherwise
# abort with only an (empty) build-log pointer. Direct `nu make.nu` invocations
# bypass bin/agentsbox's own require_podman guard, so this is the last line of defense.
def require-podman [] {
    if (which podman | is-empty) {
        error make {msg: "agentsbox: podman is required but was not found on your PATH.\n  Install Podman: https://podman.io/docs/installation\n  Then run: agentsbox doctor"}
    }
}

# Build the image. Full output goes to the build log (via tee), but the `STEP x/y`
# lines are surfaced as a single in-place progress line so `enter` isn't a silent
# wait. On failure, print the log location and exit non-zero — the try/catch turns
# a nushell external abort into that (an uncaught abort would kill the script).
def build-image [] {
    require-podman
    let log = (build-log)
    try {
        cd (root)
        print "Building sandbox environment…"
        (
            podman build -t $"($IMAGE_NAME):latest" -t $"($IMAGE_NAME):(image-tag)" .
            out+err>| tee { save --force --raw $log }
            | lines
            | each {|line|
                let m = ($line | parse --regex 'STEP (?<n>\d+)/(?<total>\d+)')
                if ($m | is-not-empty) {
                    let s = ($m | first)
                    print -n $"(char cr)(ansi -e '2K')  step ($s.n)/($s.total)"
                }
            }
            | ignore
        )
        print $"(char cr)(ansi -e '2K')Sandbox environment ready."
    } catch {
        print -e $"(char cr)(ansi -e '2K')agentsbox: image build failed; see: ($log)"
        exit 1
    }
}

## Build the image
export def "main build" [] {
    build-image
}

## Force rebuild without cache and refresh the runtime Nix store
export def "main update" [] {
    require-podman
    cd (root)
    podman build --no-cache -t $"($IMAGE_NAME):latest" -t $"($IMAGE_NAME):(image-tag)" .
    do -i { podman volume rm $NIX_VOLUME }
}

## Enter the project dev shell directly (manual use; bypasses the container)
export def "main shell" [] {
    nix develop . --extra-experimental-features "nix-command flakes"
}

## Run the agent container in WORKDIR
export def "main run" [
    --workdir: string                 # host project dir mounted at /workspace
    --auth                            # bind host port 1455:1455 for OpenCode auth
    --a2a                             # join agentsbox-net and start the A2A listener
    --a2a-agent: string = "claude"    # headless agent answering A2A messages
    --agent-name: string              # A2A alias (default: workdir basename)
    --agent: string = ""              # interactive agent to auto-launch in the session (claude/codex/opencode)
    --web                             # serve Zellij's web client on --web-port
    --web-port: int = 0               # host port mapped to container 8082 (see bin/agentsbox)
    --web-bind: string = "127.0.0.1"  # host address the web port binds to (see bin/agentsbox)
] {
    if ($workdir | is-empty) {
        print -e "WORKDIR is not set. Usage: nu make.nu run --workdir ~/src/my-project"
        exit 1
    }

    build-image

    let home = $env.HOME
    let hash = (workdir-hash $workdir)
    let name = (if ($agent_name | is-empty) { $workdir | path basename } else { $agent_name })
    let container = $"agent-($workdir | path basename)-($hash)"

    # Host config dirs the bind mounts expect to exist.
    mkdir $"($home)/.opencode/config" $"($home)/.opencode/data" $"($home)/.claude" $"($home)/.codex" $"($home)/.config/codex" $"($home)/.local/share/codex" $"($home)/.agents/skills" $"($home)/.pi/agent"
    touch $"($home)/.claude.json"

    mut run_args = [
        -it --rm --name $container
        --security-opt no-new-privileges:true
        -e XDG_CONFIG_HOME=/root/.config
        -e XDG_DATA_HOME=/root/.local/share
        -e OPENCODE_CONFIG_DIR=/root/.config/opencode
        -v $"($NIX_VOLUME):/nix"
        -v $"($PNPM_VOLUME):/pnpm-store"
        -v $"($home)/.agents:/root/.agents:Z"
        -v $"($home)/.opencode/config:/root/.config/opencode:Z"
        -v $"($home)/.opencode/data:/root/.local/share/opencode:Z"
        -p 4096
    ]

    if $auth {
        $run_args = ($run_args | append ["-p" "1455:1455"])
    }
    if $web {
        # Zellij's web client binds the container loopback, but podman's bridge DNATs
        # a published port to the container's interface IP (not loopback), so an
        # entrypoint socat relay bridges the two — without it the connect resets
        # (ERR_EMPTY_RESPONSE). Publish the relay's port (8082) to the host slot;
        # WEB_HOST/WEB_PORT tell the entrypoint the access URL to print (0.0.0.0 isn't
        # a connect target, so show loopback there — other devices substitute the
        # host's reachable IP).
        let url_host = (if $web_bind == "0.0.0.0" { "127.0.0.1" } else { $web_bind })
        $run_args = ($run_args | append ["-p" $"($web_bind):($web_port):8082" "-e" "WEB_ENABLED=1" "-e" $"WEB_PORT=($web_port)" "-e" $"WEB_HOST=($url_host)"])
    }
    if $a2a {
        $run_args = ($run_args | append [
            --network agentsbox-net
            --network-alias $name
            -e A2A_ENABLED=1
            -e $"A2A_AGENT=($a2a_agent)"
        ])
    }
    # The entrypoint reads AGENTSBOX_AGENT to open the session straight into this agent.
    if ($agent | is-not-empty) and $agent != "none" {
        $run_args = ($run_args | append ["-e" $"AGENTSBOX_AGENT=($agent)"])
    }

    $run_args = ($run_args | append [
        -e $"AGENT_NAME=($name)"
        -v $"($home)/.claude:/root/.claude:Z"
        -v $"($home)/.claude.json:/root/.claude.json:Z"
        -v $"($home)/.codex:/root/.codex:Z"
        -v $"($home)/.config/codex:/root/.config/codex:Z"
        -v $"($home)/.local/share/codex:/root/.local/share/codex:Z"
        -v $"($home)/.pi/agent:/root/.pi/agent:Z"
        -v $"($workdir):/workspace:Z"
    ])
    $run_args = ($run_args | append (secret-flags $hash))
    # [[volumes]] arrive via AGENTSBOX_VOLUMES (one `name:target` per line) from
    # bin/agentsbox — nushell list flags don't accept repeated values, so an env
    # var is the transport.
    let vol_entries = ($env.AGENTSBOX_VOLUMES? | default "" | lines | where $it != "")
    $run_args = ($run_args | append (volume-flags $hash $vol_entries))
    $run_args = ($run_args | append $"($IMAGE_NAME):(image-tag)")

    podman run ...$run_args
}

## Check host environment for required tooling
export def "main doctor" [] {
    ^$"((root))/bin/doctor"
}

## Remove the persistent Nix store volume (next run re-populates from image)
export def "main clean-nix-store" [] {
    podman volume rm $NIX_VOLUME
}

## Remove the persistent pnpm store volume (next run re-populates from image)
export def "main clean-pnpm-store" [] {
    podman volume rm $PNPM_VOLUME
}

export def main [] {
    print "Usage: nu make.nu <build|run|update|shell|doctor|clean-nix-store|clean-pnpm-store>"
    print "  run requires --workdir; see bin/agentsbox for the caller."
}
