FROM ghcr.io/anomalyco/opencode:latest

# Install dev tools
RUN apk add --no-cache \
    curl \
    git \
    bash \
    jq \
    ripgrep \
    fd \
    make \
    ca-certificates \
    less \
    ncurses \
    tree

# Allow git to work on mounted repositories in /workspace
RUN git config --system safe.directory /workspace

WORKDIR /workspace
