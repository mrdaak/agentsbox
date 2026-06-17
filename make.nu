#!/usr/bin/env nu
# make.nu — orchestration for agentsbox (build / run / update / shell / clean / doctor).
#
# Behavior-for-behavior port of the former Makefile. agentsbox no longer uses
# make as a build system (every target was .PHONY and podman does the layer
# caching), so this is a task runner — the same role toolkit.nu plays in the
# nushell repo. Invoked as `nu make.nu <subcommand> [flags]`; bin/agentsbox is
# the caller.
#
# Run from the repo root via $env.AGENTS_TOOLS_DIR (set by flake.nix in both the
# package wrapper and the dev shell), matching the Makefile's ROOT_PATH.

const IMAGE_NAME = "ai-agent"
const NIX_VOLUME = "agent-nix-store"
const PNPM_VOLUME = "agent-pnpm-store"

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

# First 8 hex of the SHA-1 of the workdir path. nushell has no `hash sha1`
# (only md5/sha256), so shell out to sha1sum — and crucially pipe the string
# WITHOUT a trailing newline, matching bin/agentsbox's `printf '%s' | shasum`
# and bin/list-secrets. The container name and secret prefixes depend on this
# lining up exactly, so do not change the hashing without re-verifying.
def workdir-hash [workdir: string] {
    $workdir | ^sha1sum | split row " " | first | str substring 0..<8
}

# The --secret flags for `podman run`, mirroring the Makefile's SECRET_FLAGS.
# `podman secret ls` has no label filter, so match by name prefix: project
# secrets (agent-<hash>-) first, then globals (agent-global-). The mount target
# lives in the agents.target label. Secrets with no target are skipped; on a
# shared target the first wins (project beats global) because uniq-by keeps the
# first occurrence — podman rejects two mounts at one path.
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

# Build the image. Full output still goes to the build log (via tee), but the
# `STEP x/y` lines podman emits are surfaced as a single in-place progress line
# so `enter` isn't a silent wait. On failure print the log location to stderr
# and exit non-zero. A failed external aborts the script in nushell, so the
# try/catch is what turns that into the Makefile's behavior.
def build-image [] {
    let log = (build-log)
    try {
        cd (root)
        print "Building sandbox environment…"
        (
            podman build -t $"($IMAGE_NAME):latest" .
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
    cd (root)
    podman build --no-cache -t $"($IMAGE_NAME):latest" .
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
    mkdir $"($home)/.opencode/config" $"($home)/.opencode/data" $"($home)/.claude" $"($home)/.codex" $"($home)/.config/codex" $"($home)/.local/share/codex" $"($home)/.agents/skills"
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
        # Zellij's web client binds the container loopback; a socat relay in the
        # entrypoint bridges the container's external interface to it. podman's
        # bridge network DNATs a published port to the container's interface IP,
        # not its loopback, so without the relay a loopback-only server is
        # unreachable (the connect resets: ERR_EMPTY_RESPONSE). Publish the
        # relay's port (8082) to the chosen host slot, bound to --web-bind.
        # WEB_HOST/WEB_PORT tell the entrypoint what to print in the access URL:
        # the bind address, except 0.0.0.0 isn't a connect target so show
        # loopback (other devices substitute the host's reachable IP).
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

    $run_args = ($run_args | append [
        -e $"AGENT_NAME=($name)"
        -v $"($home)/.claude:/root/.claude:Z"
        -v $"($home)/.claude.json:/root/.claude.json:Z"
        -v $"($home)/.codex:/root/.codex:Z"
        -v $"($home)/.config/codex:/root/.config/codex:Z"
        -v $"($home)/.local/share/codex:/root/.local/share/codex:Z"
        -v $"($workdir):/workspace:Z"
    ])
    $run_args = ($run_args | append (secret-flags $hash))
    $run_args = ($run_args | append $"($IMAGE_NAME):latest")

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
