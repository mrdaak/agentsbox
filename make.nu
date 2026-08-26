#!/usr/bin/env nu
# make.nu — task runner for agentsbox (build / run / rebuild / shell / clean / doctor).
# Invoked by bin/agentsbox as `nu make.nu <subcommand> [flags]`; resolves the repo
# root via $env.AGENTS_TOOLS_DIR (set by flake.nix).

const IMAGE_NAME = "agentsbox"
const NIX_VOLUME = "agent-nix-store"
const PNPM_VOLUME = "agent-pnpm-store"

# Image tag: AGENTSBOX_VERSION (set by flake.nix), falling back to "latest" for a
# raw `nu make.nu` call. The versioned tag pins the running image to the installed
# agentsbox; build/rebuild write both it and `latest` so a failed rebuild leaves the
# previous version's tag as a rollback target.
def image-tag [] {
    $env.AGENTSBOX_VERSION? | default "latest"
}

# Full sha256 image ID of the agentsbox image we are about to run. 'main run'
# calls build-image first, so the tag exists by the time this is called.
def image-digest [] {
    ^podman image inspect $"($IMAGE_NAME):(image-tag)" --format '{{.Id}}'
        | str trim
}

# Ensure the shared /nix named volume exists and is stamped with the image
# digest of the agentsbox image we are about to run. Podman seeds a named
# volume from image content ONLY when the volume is empty; a pre-existing
# stale volume silently shadows a rebuilt image. We stamp the volume's
# agents.image label on first creation and, on each run, compare it to the
# current image's digest. On mismatch we drop and reseed; on a missing label
# (a legacy volume from before this code shipped) we relabel in place so the
# first run after upgrade isn't a surprise full re-copy, and let the next
# real image bump trigger the drop.
def ensure-nix-volume-stamped [] {
    let digest = (image-digest)
    # Podman's {{.Id}} is a bare 64-char hex digest; Docker prefixes 'sha256:'.
    # Accept either — the stamp/compare below only needs a stable, non-empty ID.
    if ($digest | is-empty) or not ($digest =~ '^(sha256:)?[0-9a-fA-F]{64}$') {
        error make {msg: "agentsbox: could not resolve image digest for the /nix volume stamp (is the image built?)"}
    }
    let existing = (do -i { podman volume ls --format '{{.Name}}' } | default "" | lines)
    if ($NIX_VOLUME not-in $existing) {
        podman volume create --label $"agents.image=($digest)" $NIX_VOLUME out+err>| ignore
        return
    }
    let stamped = (do -i {
        podman volume inspect $NIX_VOLUME --format '{{index .Labels "agents.image"}}'
    } | default "" | str trim)
    if $stamped == $digest { return }
    if $stamped == "" {
        # Legacy pre-stamp volume: relabel in place. If `podman volume label`
        # is unavailable (older Podman), fall back to drop+reseed with a loud
        # message so the one-time full re-copy is at least explained.
        let relabeled = (try {
            podman volume label $NIX_VOLUME $"agents.image=($digest)" out+err>| ignore
            true
        } catch { false })
        if $relabeled {
            print -e "agentsbox: stamped the existing /nix store volume (legacy, first run after upgrade)"
            return
        }
        print -e "agentsbox: the /nix store volume predates image-stamping and `podman volume label` is unavailable; dropping and reseeding from the current image (one-time full re-copy)…"
        do -i { podman volume rm $NIX_VOLUME } | ignore
        podman volume create --label $"agents.image=($digest)" $NIX_VOLUME out+err>| ignore
        return
    }
    print -e $"agentsbox: the /nix store volume is stale \(was built for ($stamped), current image is ($digest)\); rebuilding it from the new image…"
    do -i { podman volume rm $NIX_VOLUME } | ignore
    podman volume create --label $"agents.image=($digest)" $NIX_VOLUME out+err>| ignore
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

# The agents baked into the image (global-only key in ~/.config/agentsbox.toml).
# Falls back to all four when the key is missing or the file absent.
const ALL_AGENTS = [claude codex pi opencode]

def resolve-installed-agents [] {
    let cfg = ($env.XDG_CONFIG_HOME? | default ($"($env.HOME)/.config"))
    let file = ($"($cfg)/agentsbox.toml")
    let parsed = (try { open $file | get installed_agents | to text | lines | where $it != "" } catch { [] })
    if ($parsed | is-empty) { $ALL_AGENTS } else { $parsed }
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
    # Podman secrets default to root:root. Keep secrets owner-readable only,
    # but assign them to the non-root user that runs the agent shell.
    | each {|s| ["--secret" $"($s.name),target=($s.target),uid=1000,gid=1000,mode=0400"] }
    | flatten
}

# In-container paths already bound by built-in mounts (run_args) and secrets —
# config-declared mounts may not reuse one, since podman rejects two mounts at
# the same path and we want to fail with a clear message rather than podman's.
def built-in-mounts [] {
    [ /workspace /nix /pnpm-store
      /home/agent/.agents /home/agent/.claude /home/agent/.claude.json
      /home/agent/.codex /home/agent/.config/codex /home/agent/.local/share/codex
      /home/agent/.pi/agent /home/agent/.config/opencode /home/agent/.local/share/opencode ]
}

# -v flags for declared [[volumes]] (each entry "name:target"). Project entries
# are prefixed agent-<hash>-<name>, globals agent-global-<name> (mirroring
# secret-flags); both are created lazily and mounted with :Z. Project wins on a
# shared target (podman rejects two mounts at one path). Name shape, absolute
# target, and built-in-mount collisions are hard errors.
def volume-flags [hash: string, project_entries: list, global_entries: list] {
    let mounts = (built-in-mounts)
    let existing = (do -i { podman volume ls --format '{{.Name}}' } | default "" | lines)
    let parse = {|entry, prefix|
        let parts = ($entry | split row ":")
        if ($parts | length) != 2 {
            error make {msg: $"agentsbox: malformed volume '($entry)' \(expected name:target)"}
        }
        let name = ($parts | first)
        let target = ($parts | last)
        if ($name | is-empty) {
            error make {msg: $"agentsbox: volume entry '($entry)' has an empty name"}
        }
        if not ($name =~ '^[A-Za-z0-9_.-]+$') {
            error make {msg: $"agentsbox: invalid volume name '($name)' \(allowed: A-Z a-z 0-9 _ . -)"}
        }
        if ($target | is-empty) or not ($target | str starts-with "/") {
            error make {msg: $"agentsbox: volume target '($target)' must be an absolute path"}
        }
        if ($target in $mounts) {
            error make {msg: $"agentsbox: volume target '($target)' collides with a built-in mount"}
        }
        {target: $target, effective: $"($prefix)($name)"}
    }
    let parsed = (
        ($project_entries | each {|e| do $parse $e $"agent-($hash)-"})
        ++ ($global_entries | each {|e| do $parse $e "agent-global-"})
    )
    if ($parsed | is-empty) { return [] }
    # Create every declared volume, including ones shadowed on this run — they
    # still mount in projects that don't shadow them.
    $parsed | each {|v|
        if ($v.effective not-in $existing) {
            podman volume create $v.effective out+err>| ignore
        }
    } | ignore
    $parsed
    | uniq-by target
    | each {|v| ["-v" $"($v.effective):($v.target):Z"] }
    | flatten
}

# -v flags for declared [[bind_mounts]] (each entry
# "source<TAB>target<TAB>readonly"). Project entries come before globals, so
# uniq-by target gives project bind mounts precedence on shared targets.
def bind-mount-flags [project_entries: list, global_entries: list] {
    let mounts = (built-in-mounts)
    let home = $env.HOME
    let expand_source = {|source|
        if $source == "~" {
            $home
        } else if ($source | str starts-with "~/") {
            $"($home)($source | str substring 1..)"
        } else {
            $source
        }
    }
    let parse = {|entry|
        let parts = ($entry | split row (char tab))
        if ($parts | length) != 3 {
            error make {msg: $"agentsbox: malformed bind_mount '($entry)' \(expected source<TAB>target<TAB>readonly)"}
        }
        let raw_source = ($parts | first)
        let expanded_source = (do $expand_source $raw_source)
        let target = ($parts | get 1)
        let readonly = ($parts | last)
        if ($raw_source | is-empty) {
            error make {msg: "agentsbox: bind_mount source must be non-empty"}
        }
        if not ($expanded_source | path exists) {
            error make {msg: $"agentsbox: bind_mount source '($raw_source)' does not exist"}
        }
        let source = ($expanded_source | path expand --no-symlink)
        if ($target | is-empty) or not ($target | str starts-with "/") {
            error make {msg: $"agentsbox: bind_mount target '($target)' must be an absolute path"}
        }
        if ($target in $mounts) {
            error make {msg: $"agentsbox: bind_mount target '($target)' collides with a built-in mount"}
        }
        if ($readonly != "true") and ($readonly != "false") {
            error make {msg: $"agentsbox: bind_mount readonly for target '($target)' must be true or false"}
        }
        let mode = (if $readonly == "true" { "ro,Z" } else { "Z" })
        {target: $target, flag: $"($source):($target):($mode)"}
    }
    let parsed = (
        ($project_entries | each {|e| do $parse $e})
        ++ ($global_entries | each {|e| do $parse $e})
    )
    $parsed
    | uniq-by target
    | each {|m| ["-v" $m.flag] }
    | flatten
}

# -p flags for declared [[ports]] (each entry "host:container:bind", project-only —
# no global equivalent, host ports are scarce and not shareable like volumes).
# bind defaults to loopback (127.0.0.1). Skipped under host/container: networks
# where podman rejects -p (mirrors --auth/--web); main run gates on no_publish.
def port-flags [entries: list] {
    if ($entries | is-empty) { return [] }
    $entries
    | each {|e|
        let parts = ($e | split row ":")
        if ($parts | length) != 3 {
            error make {msg: $"agentsbox: malformed port '($e)' \(expected host:container:bind)"}
        }
        let host = ($parts | first)
        let container = ($parts | get 1)
        let bind = ($parts | last)
        if not ($host =~ '^[0-9]+$') {
            error make {msg: $"agentsbox: port host '($host)' must be a number \(in '($e)')"}
        }
        if not ($container =~ '^[0-9]+$') {
            error make {msg: $"agentsbox: port container '($container)' must be a number \(in '($e)')"}
        }
        let b = (if ($bind | is-empty) { "127.0.0.1" } else { $bind })
        ["-p" $"($b):($host):($container)"]
    }
    | flatten
}

# Validate global auth callback relays and emit their loopback-only -p flags.
# Each entry is host:container:target:bind; the entrypoint forwards container
# to the loopback-only target with socat after Podman has started the container.
def auth-callback-relay-flags [entries: list, project_ports: list, web: bool, web_port: int, web_bind: string] {
    if ($entries | is-empty) {
        error make {msg: "agentsbox: --auth requires auth_callback_relays in ~/.config/agentsbox.toml"}
    }
    let relays = ($entries | each {|e|
        let parts = ($e | split row ":")
        if ($parts | length) != 4 {
            error make {msg: $"agentsbox: malformed auth callback relay '($e)' \(expected host:container:target:bind)"}
        }
        let host = ($parts | first)
        let container = ($parts | get 1)
        let target = ($parts | get 2)
        let bind = (if ($parts | last | is-empty) { "127.0.0.1" } else { $parts | last })
        for port in [$host $container $target] {
            if not ($port =~ '^[0-9]+$') or (($port | into int) < 1) or (($port | into int) > 65535) {
                error make {msg: $"agentsbox: auth callback relay ports must be integers from 1 to 65535 \(in '($e)')"}
            }
        }
        if $container == $target {
            error make {msg: $"agentsbox: auth callback relay container port must differ from target \(in '($e)')"}
        }
        {host: $host, container: $container, target: $target, bind: $bind}
    })
    let host_keys = ($relays | each {|r| $"($r.bind):($r.host)"})
    if ($host_keys | uniq | length) != ($host_keys | length) {
        error make {msg: "agentsbox: auth callback relays duplicate a host bind and port"}
    }
    let container_ports = ($relays | get container)
    if ($container_ports | uniq | length) != ($container_ports | length) {
        error make {msg: "agentsbox: auth callback relays duplicate a container port"}
    }
    let project_container_ports = ($project_ports | each {|p|
        let parts = ($p | split row ":")
        if ($parts | length) == 3 { $parts | get 1 } else { "" }
    })
    if ($container_ports | any {|p| $p in $project_container_ports }) {
        error make {msg: "agentsbox: auth callback relay container port conflicts with [[ports]]"}
    }
    let project_host_keys = ($project_ports | each {|p|
        let parts = ($p | split row ":")
        if ($parts | length) == 3 {
            let bind = (if ($parts | last | is-empty) { "127.0.0.1" } else { $parts | last })
            $"($bind):($parts | first)"
        } else { "" }
    })
    if ($host_keys | any {|p| $p in $project_host_keys }) {
        error make {msg: "agentsbox: auth callback relay host bind and port conflicts with [[ports]]"}
    }
    if $web and ($container_ports | any {|p| $p == "8082" }) {
        error make {msg: "agentsbox: auth callback relay container port 8082 conflicts with --web"}
    }
    let web_host_key = $"($web_bind):($web_port)"
    if $web and $web_port > 0 and ($host_keys | any {|p| $p == $web_host_key }) {
        error make {msg: "agentsbox: auth callback relay host bind and port conflicts with --web"}
    }
    $relays | each {|r| ["-p" $"($r.bind):($r.host):($r.container)"] } | flatten
}

# Confirm podman is on PATH before reaching `podman build`, which would otherwise
# abort with only an (empty) build-log pointer. Direct `nu make.nu` invocations
# bypass bin/agentsbox's own require_podman guard, so this is the last line of defense.
def require-podman [] {
    if (which podman | is-empty) {
        error make {msg: "agentsbox: podman is required but was not found on your PATH.\n  Install Podman: https://podman.io/docs/installation\n  Then run: agentsbox doctor"}
    }
}

# keep-id maps the invoking user onto agent's uid so the bind mounts stay
# writable. `podman machine` (macOS/Windows) rejects --userns as mutually
# exclusive with the id-maps it already applies to the VM's shared dirs, so the
# flag is for a local Linux podman only.
def userns-flags [] {
    let remote = (do -i { ^podman info --format '{{.Host.ServiceIsRemote}}' } | default "" | str trim)
    if $remote == "false" { ["--userns=keep-id:uid=1000,gid=1000"] } else { [] }
}

# Build the image. Full output goes to the build log (via tee), but the `STEP x/y`
# lines are surfaced as a single in-place progress line so `enter` isn't a silent
# wait. On failure, print the log location and exit non-zero — the try/catch turns
# a nushell external abort into that (an uncaught abort would kill the script).
def build-image [] {
    require-podman
    let log = (build-log)
    let agents = (resolve-installed-agents)
    try {
        cd (root)
        print "Building sandbox environment…"
        (
            podman build --build-arg $"AGENTSBOX_INSTALLED_AGENTS=($agents | str join (char nl))" -t $"($IMAGE_NAME):latest" -t $"($IMAGE_NAME):(image-tag)" .
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
        let digest = (do -i { image-digest } | default "")
        # Podman's {{.Id}} is a bare 64-char hex digest; Docker prefixes 'sha256:'.
        # Accept either so this guard doesn't false-positive on a successful
        # Podman build and mislabel it as a failure.
        if ($digest | is-empty) or not ($digest =~ '^(sha256:)?[0-9a-fA-F]{64}$') {
            print -e $"(char cr)(ansi -e '2K')agentsbox: image build failed; see: ($log)"
            exit 1
        }
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
export def "main rebuild" [] {
    require-podman
    cd (root)
    let agents = (resolve-installed-agents)
    podman build --no-cache --build-arg $"AGENTSBOX_INSTALLED_AGENTS=($agents | str join (char nl))" -t $"($IMAGE_NAME):latest" -t $"($IMAGE_NAME):(image-tag)" .
    # rebuild is the explicit "nuke" path; ensure-nix-volume-stamped (on the
    # next run) recreates a stamped volume; gc-nix-store is the lean path.
    do -i { podman volume rm $NIX_VOLUME }
}

## Enter the project dev shell directly (manual use; bypasses the container)
export def "main shell" [] {
    nix develop . --extra-experimental-features "nix-command flakes"
}

## Run the agent container in WORKDIR
export def "main run" [
    --workdir: string                 # host project dir mounted at /workspace
    --auth                            # enable global OAuth/MCP callback relays
    --a2a                             # join agentsbox-net and start the A2A listener
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

    ensure-nix-volume-stamped

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
        --cap-drop=ALL
        --pids-limit=2048
        --memory=8g
        --user agent
        -e XDG_CONFIG_HOME=/home/agent/.config
        -e XDG_DATA_HOME=/home/agent/.local/share
        -e OPENCODE_CONFIG_DIR=/home/agent/.config/opencode
        # :U chowns the volume to the box user; without it the store seeds
        # root-owned and single-user nix cannot lock /nix/var/nix/db.
        -v $"($NIX_VOLUME):/nix:U"
        -v $"($PNPM_VOLUME):/pnpm-store:U"
        -v $"($home)/.agents:/home/agent/.agents:Z"
        -v $"($home)/.opencode/config:/home/agent/.config/opencode:Z"
        -v $"($home)/.opencode/data:/home/agent/.local/share/opencode:Z"
    ]
    $run_args = ($run_args | append (userns-flags))

    let network = ($env.AGENTSBOX_NETWORK? | default "" | str trim)
    let no_publish = ($network == "host" or ($network | str starts-with "container:"))
    let project_ports = ($env.AGENTSBOX_PORTS? | default "" | lines | where $it != "")
    let auth_callback_relays = ($env.AGENTSBOX_AUTH_CALLBACK_RELAYS? | default "" | lines | where $it != "")
    if $no_publish and ($auth or $web or ($project_ports | is-not-empty)) {
        if $auth {
            print -e $"agentsbox: --network '($network)' can't publish auth callback relays"
            exit 1
        }
        print -e $"agentsbox: --network '($network)' can't publish ports; ignoring --web/[[ports]]"
    }
    if $network != "" and $a2a {
        print -e $"agentsbox: --network '($network)' is incompatible with --a2a, which requires agentsbox-net; aborting"
        exit 1
    }

    if $auth and not $no_publish {
        $run_args = ($run_args | append (auth-callback-relay-flags $auth_callback_relays $project_ports $web $web_port $web_bind))
        $run_args = ($run_args | append ["-e" $"AGENTSBOX_AUTH_CALLBACK_RELAYS=($auth_callback_relays | str join (char nl))"])
    }
    if $web and not $no_publish {
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
        # A2A backs onto the same agent as the session (--agent / AGENTSBOX_AGENT).
        # bin/agentsbox resolves one before reaching here; none set is an error,
        # not a guess — an unconfigured agent would fail every request.
        if ($agent | is-empty) or $agent == "none" {
            print -e "agentsbox: --a2a requires --agent (or a configured 'agent' in config); aborting"
            exit 1
        }
        $run_args = ($run_args | append [
            --network agentsbox-net
            --network-alias $name
            -e A2A_ENABLED=1
        ])
    }
    if $network != "" {
        $run_args = ($run_args | append ["--network" $network])
    }
    # The entrypoint reads AGENTSBOX_AGENT to open the session straight into
    # this agent; listen-message reads it too as the A2A backend.
    if ($agent | is-not-empty) and $agent != "none" {
        $run_args = ($run_args | append ["-e" $"AGENTSBOX_AGENT=($agent)"])
    }

    $run_args = ($run_args | append [
        -e $"AGENT_NAME=($name)"
        -v $"($home)/.claude:/home/agent/.claude:Z"
        -v $"($home)/.claude.json:/home/agent/.claude.json:Z"
        -v $"($home)/.codex:/home/agent/.codex:Z"
        -v $"($home)/.config/codex:/home/agent/.config/codex:Z"
        -v $"($home)/.local/share/codex:/home/agent/.local/share/codex:Z"
        -v $"($home)/.pi/agent:/home/agent/.pi/agent:Z"
        -v $"($workdir):/workspace:Z"
    ])
    $run_args = ($run_args | append (secret-flags $hash))
    # [[volumes]] arrive via AGENTSBOX_VOLUMES (project) and AGENTSBOX_GLOBAL_VOLUMES
    # (global) from bin/agentsbox — nushell list flags don't accept repeated values,
    # so env vars are the transport.
    let project_volumes = ($env.AGENTSBOX_VOLUMES? | default "" | lines | where $it != "")
    let global_volumes = ($env.AGENTSBOX_GLOBAL_VOLUMES? | default "" | lines | where $it != "")
    $run_args = ($run_args | append (volume-flags $hash $project_volumes $global_volumes))
    # [[bind_mounts]] share the same project-over-global target precedence as
    # named volumes, but mount explicit host paths and never create Podman volumes.
    let project_bind_mounts = ($env.AGENTSBOX_BIND_MOUNTS? | default "" | lines | where $it != "")
    let global_bind_mounts = ($env.AGENTSBOX_GLOBAL_BIND_MOUNTS? | default "" | lines | where $it != "")
    $run_args = ($run_args | append (bind-mount-flags $project_bind_mounts $global_bind_mounts))
    if not $no_publish {
        $run_args = ($run_args | append (port-flags $project_ports))
    }
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

## In-place garbage collection of the shared /nix store volume (does NOT drop
## it). Refuses while a session is live: the gc container scans only its own
## PID namespace, so a running box's devShell (rooted only by its shell
## process) would look unreachable and be deleted out from under it.
export def "main gc-nix-store" [] {
    require-podman
    let live = (do -i {
        podman ps --filter "name=^agent-" --format '{{.Names}}'
    } | default "" | lines | where $it != "")
    if not ($live | is-empty) {
        print -e $"agentsbox: refusing to gc — ($live | length) session\(s\) running: ($live | str join ', ')"
        print -e "  Stop them first (exit the shells), then re-run: agentsbox gc"
        exit 1
    }
    print "Running nix-collect-garbage on the shared /nix store…"
    let vol = $"($NIX_VOLUME):/nix:U"
    let img = $"($IMAGE_NAME):(image-tag)"
    # --entrypoint because shell-entrypoint ignores "$@" and launches Zellij,
    # so a trailing command would never run.
    let gc_args = ([
        --rm
        --security-opt no-new-privileges:true
        --cap-drop=ALL
        --pids-limit=2048
        --memory=8g
        --user agent
        --entrypoint nix-collect-garbage
    ] | append (userns-flags) | append [-v $vol $img -d])
    podman run ...$gc_args
    print "Done."
}

## Remove the persistent pnpm store volume (next run re-populates from image)
export def "main clean-pnpm-store" [] {
    podman volume rm $PNPM_VOLUME
}

## One-time interactive agent selection (first-run wizard). Renders a
## multi-select via nushell's `input list --multi`; prints the chosen agents
## one-per-line on success. ESC/Ctrl-C cancels (exits non-zero, no output). An
## empty submit re-prompts since >=1 agent is required. Called by bin/agentsbox
## only when stdin is a TTY and no installed_agents key is set yet.
export def "main select-agents" [] {
    let p = "Select agents to install in the image (Space=toggle, Enter=confirm, Esc=cancel):"
    loop {
        let r = ($ALL_AGENTS | input list --multi $p)
        if $r == null { exit 1 }
        let chosen = ($r | default [])
        if ($chosen | is-not-empty) {
            $chosen | each { |a| print $a }
            return
        }
        print -e "Select at least one agent."
    }
}

## Pick one installed agent to back A2A (single-select). Called by bin/agentsbox
## only when --a2a is set and no agent resolved from flag/config. The installed
## set arrives one-per-line in AGENTSBOX_A2A_CHOICES (env transport, same pattern
## as AGENTSBOX_VOLUMES) so the choice is constrained to agents baked into the
## image. Prints the chosen agent on success; ESC/Ctrl-C cancels (exits non-zero,
## no output). The caller persists the pick so it never re-prompts.
export def "main select-a2a-agent" [] {
    let choices = ($env.AGENTSBOX_A2A_CHOICES? | default "" | lines | where $it != "")
    if ($choices | is-empty) { exit 1 }
    let p = "No agent configured for this project. A2A needs one — select an installed agent (Enter=confirm, Esc=cancel):"
    let r = ($choices | input list $p)
    if ($r | is-empty) { exit 1 }
    print $r
}

export def main [] {
    print "Usage: nu make.nu <build|run|rebuild|shell|doctor|clean-nix-store|gc-nix-store|clean-pnpm-store>"
    print "  run requires --workdir; see bin/agentsbox for the caller."
}
