FROM ghcr.io/anomalyco/opencode:latest

# Install additional packages
RUN apk add --no-cache \
    curl \
    git

# Set working directory
WORKDIR /workspace
