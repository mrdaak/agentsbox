FROM ghcr.io/nixos/nix:2.34.7@sha256:bf1d938835ab96312f098fa6c2e9cab367728e0aad0646ee3e02a787c80d8fb8

# Enable flakes and use single-user builds inside the rootless container.
RUN printf 'experimental-features = nix-command flakes\nbuild-users-group =\n' >> /etc/nix/nix.conf

# Install all dev tools via nix in a single profile generation. packages.nix is
# the source of truth for the tool set; it imports the version-pinned claude-code.nix, codex.nix, and pi.nix.
# --priority resolves collisions against packages already present in the base image's profile.
COPY packages.nix claude-code.nix codex.nix pi.nix /tmp/nix/
RUN nix profile add --priority 4 -f /tmp/nix/packages.nix \
 && nix-collect-garbage -d \
 && rm -rf /tmp/nix

# Set up XDG directories for proper config loading
ENV XDG_CONFIG_HOME=/root/.config
ENV XDG_DATA_HOME=/root/.local/share
ENV OPENCODE_CONFIG_DIR=/root/.config/opencode

# Configure pnpm to use a shared store at /pnpm-store. pnpm 11 reads YAML
# config from $XDG_CONFIG_HOME/pnpm/config.yaml; it ignores npm_config_* env
# vars and /etc/npmrc, and would otherwise place the store at the mount-point
# root of /workspace.
RUN mkdir -p /root/.config/pnpm \
 && printf 'storeDir: /pnpm-store\npackageImportMethod: copy\n' \
    > /root/.config/pnpm/config.yaml

# Bake in the Zellij config. It used to be bind-mounted from the package at run
# time, but on macOS podman runs in a Linux VM that can't see the host's
# /nix/store (where the package lives), so the mount failed with `statfs ... no
# such file or directory`. Copying it into the image at build time works on every
# host: the build context streams from the host, unlike runtime bind mounts.
# zellij reads $XDG_CONFIG_HOME/zellij/config.kdl (XDG_CONFIG_HOME=/root/.config).
COPY zellij-config.kdl /root/.config/zellij/config.kdl

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
