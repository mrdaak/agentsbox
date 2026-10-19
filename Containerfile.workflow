FROM ghcr.io/nixos/nix:2.34.7@sha256:bf1d938835ab96312f098fa6c2e9cab367728e0aad0646ee3e02a787c80d8fb8

RUN printf 'experimental-features = nix-command flakes\nbuild-users-group =\n' >> /etc/nix/nix.conf

ARG AGENTSBOX_AGENT
ARG AGENTSBOX_TOOLS
COPY workflow-nixpkgs.nix workflow-packages.nix claude-code.nix codex.nix pi.nix opencode.nix /tmp/nix/
RUN nix profile add --priority 4 -f /tmp/nix/workflow-packages.nix \
 && nix-collect-garbage -d \
 && rm -rf /tmp/nix
RUN git config --system safe.directory /workspace

RUN printf 'agent:x:1000:1000::/home/agent:/bin/sh\n' >> /etc/passwd \
 && printf 'agent:x:1000:\n' >> /etc/group \
 && printf 'agent:!:19000:0:99999:7:::\n' >> /etc/shadow \
 && mkdir -p /home/agent /reports /run/secrets

COPY workflow /opt/agentsbox/workflow
COPY workflow-nixpkgs.nix /opt/agentsbox/workflow-nixpkgs.nix
RUN if [ -f /opt/agentsbox/workflow/rules.nix ]; then \
      nix profile add --priority 4 -f /opt/agentsbox/workflow/rules.nix --arg pkgs 'import /opt/agentsbox/workflow-nixpkgs.nix'; \
    fi \
 && chmod +x /opt/agentsbox/workflow/run \
 && chown -R agent:agent /home/agent /reports \
 && nix-collect-garbage -d

ENV HOME=/home/agent
ENV XDG_CONFIG_HOME=/home/agent/.config
ENV XDG_DATA_HOME=/home/agent/.local/share
WORKDIR /workspace
USER agent
ENTRYPOINT ["/opt/agentsbox/workflow/run"]
