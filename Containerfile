FROM ghcr.io/nixos/nix:2.34.7@sha256:bf1d938835ab96312f098fa6c2e9cab367728e0aad0646ee3e02a787c80d8fb8

# Enable flakes and install nixpkgs
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

# Update nixpkgs channel and install packages
RUN nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs && \
    nix-channel --update

# Install all dev tools via nix in a single profile generation. packages.nix is
# the source of truth for the tool set; it imports the version-pinned claude-code.nix and codex.nix.
# --priority resolves collisions against packages already present in the base image's profile.
COPY packages.nix claude-code.nix codex.nix /tmp/nix/
RUN nix profile add --priority 4 -f /tmp/nix/packages.nix

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

# Allow git to work on mounted repositories in /workspace
RUN git config --system safe.directory /workspace

# Copy entrypoint script
COPY bin/shell-entrypoint /usr/local/bin/
RUN chmod +x /usr/local/bin/shell-entrypoint

WORKDIR /workspace

# Set entrypoint to auto-detect nix shells
ENTRYPOINT ["/usr/local/bin/shell-entrypoint"]
CMD []
