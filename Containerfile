FROM ghcr.io/nixos/nix:2.34.7@sha256:bf1d938835ab96312f098fa6c2e9cab367728e0aad0646ee3e02a787c80d8fb8

# Enable flakes and use single-user builds inside the rootless container.
RUN printf 'experimental-features = nix-command flakes\nbuild-users-group =\n' >> /etc/nix/nix.conf

# Install all dev tools via nix in a single profile generation. packages.nix is
# the source of truth for the tool set; it imports the version-pinned claude-code.nix, codex.nix, and pi.nix.
# --priority resolves collisions against packages already present in the base image's profile.
# AGENTSBOX_INSTALLED_AGENTS selects which agents to bake in (empty default => all four).
ARG AGENTSBOX_INSTALLED_AGENTS=
COPY packages.nix claude-code.nix codex.nix opencode.nix pi.nix /tmp/nix/
RUN echo "$AGENTSBOX_INSTALLED_AGENTS" \
 && nix profile add --priority 4 -f /tmp/nix/packages.nix \
 && nix-collect-garbage -d \
 && rm -rf /tmp/nix

# Create the non-root in-container user. The box runs as this user by default
# (`--user agent` in make.nu, plus --userns=keep-id on a Linux host, maps the
# invoking host user onto this uid so /workspace writes come out owned by
# them). The base nix image ships no useradd/adduser, so write the
# passwd/group/shadow entries directly — uid/gid 1000, home /home/agent,
# shell /bin/bash match useradd's defaults.
RUN printf 'agent:x:1000:1000::/home/agent:/bin/bash\n' >> /etc/passwd \
 && printf 'agent:x:1000:\n' >> /etc/group \
 && printf 'agent:!:19000:0:99999:7:::\n' >> /etc/shadow \
 && mkdir -p /home/agent

# XDG ENVs stay at /root for the build-time `nix profile add` (which runs as
# root and writes /root/.nix-profile). make.nu overrides these at run with
# -e XDG_CONFIG_HOME=/home/agent/.config, so the running box uses /home/agent.
ENV XDG_CONFIG_HOME=/root/.config
ENV XDG_DATA_HOME=/root/.local/share
ENV OPENCODE_CONFIG_DIR=/root/.config/opencode

# pnpm + Zellij config written to /home/agent so the running box (as agent)
# finds them. /root copies are gone — one path, the runtime one.
#
# .local/share must pre-exist owned by agent: make.nu only bind-mounts specific
# children of it, so an absent parent gets auto-created by Podman as root,
# blocking agent from writing siblings there (e.g. Zellij's web token store).
RUN mkdir -p /home/agent/.config/pnpm /home/agent/.config/zellij /home/agent/.local/share \
 && printf 'storeDir: /pnpm-store\npackageImportMethod: copy\n' \
    > /home/agent/.config/pnpm/config.yaml \
 && chown -R agent:agent /home/agent

COPY zellij-config.kdl /home/agent/.config/zellij/config.kdl

COPY skills /opt/agentsbox/skills
RUN chmod -R a+rX /opt/agentsbox/skills

# Allow git to work on mounted repositories in /workspace
RUN git config --system safe.directory /workspace

# Copy entrypoint and A2A scripts onto PATH. The nix base image ships a minimal
# PATH that does not include /usr/local/bin, so add it explicitly — otherwise the
# entrypoint can't find `listen-message` and `send-message` is unreachable in the
# shell.
COPY bin/shell-entrypoint bin/listen-message bin/send-message /usr/local/bin/
COPY bin/codex-container /usr/local/bin/codex
RUN chmod +x /usr/local/bin/shell-entrypoint \
             /usr/local/bin/listen-message \
             /usr/local/bin/send-message \
             /usr/local/bin/codex
ENV PATH=/usr/local/bin:$PATH

WORKDIR /workspace

# Set entrypoint to auto-detect nix shells
ENTRYPOINT ["/usr/local/bin/shell-entrypoint"]
CMD []
