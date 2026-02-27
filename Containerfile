FROM nixos/nix:latest

# Enable flakes and install nixpkgs
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

# Update nixpkgs channel and install packages
RUN nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs && \
    nix-channel --update

# Install dev tools via nix
RUN nix-env -iA nixpkgs.bun nixpkgs.nodejs_22 nixpkgs.gitMinimal nixpkgs.jq nixpkgs.ripgrep nixpkgs.fd nixpkgs.gnumake \
    nixpkgs.cacert nixpkgs.less nixpkgs.ncurses nixpkgs.tree nixpkgs.bash nixpkgs.curl nixpkgs.gnutar nixpkgs.opencode

# Allow git to work on mounted repositories in /workspace
RUN git config --system safe.directory /workspace

# Set up XDG directories for proper config loading
ENV XDG_CONFIG_HOME=/root/.config
ENV XDG_DATA_HOME=/root/.local/share
ENV OPENCODE_CONFIG_DIR=/root/.config/opencode

# Copy entrypoint script
COPY bin/opencode-entrypoint /usr/local/bin/
RUN chmod +x /usr/local/bin/opencode-entrypoint

WORKDIR /workspace

# Set entrypoint to auto-detect nix shells
ENTRYPOINT ["/usr/local/bin/opencode-entrypoint"]
CMD []
