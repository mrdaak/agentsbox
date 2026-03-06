IMAGE_NAME := ai-agent
NIX_VOLUME := agent-nix-store

SHELL := /usr/bin/env bash
ROOT_PATH = ${AGENTS_TOOLS_DIR}

.PHONY: shell build update run clean-nix-store

shell:
	nix develop . --extra-experimental-features "nix-command flakes"

## Build the custom OpenCode image
build:
	cd ${ROOT_PATH} && podman build -t $(IMAGE_NAME):latest .

## Force rebuild without cache
update:
	cd ${ROOT_PATH} && podman build --no-cache -t $(IMAGE_NAME):latest .

## Run OpenCode in the given WORKDIR (defaults to requiring explicit WORKDIR)
run: build
# ifndef AGENT
# 	$(error AGENT is not set. Usage: make run AGENT=claude WORKDIR=~/src/my-project)
# endif
ifndef WORKDIR
	$(error WORKDIR is not set. Usage: make run AGENT=claude WORKDIR=~/src/my-project)
endif
	mkdir -p ~/.opencode/config ~/.opencode/data ~/.claude
	podman volume exists $(NIX_VOLUME) || podman volume create $(NIX_VOLUME)
	podman run -it --rm --name opencode-$(notdir $(WORKDIR)) \
		--security-opt no-new-privileges:true \
		-e XDG_CONFIG_HOME=/root/.config \
		-e XDG_DATA_HOME=/root/.local/share \
		-e OPENCODE_CONFIG_DIR=/root/.config/opencode \
		-v $(NIX_VOLUME):/nix \
		-v ~/.opencode/config:/root/.config/opencode:Z \
		-v ~/.opencode/data:/root/.local/share/opencode:Z \
		-v ~/.claude:/root/.claude:Z \
		-v ~/.claude.json:/root/.claude.json:Z \
		-v $(WORKDIR):/workspace:Z \
		$(IMAGE_NAME):latest

## Remove the persistent Nix store volume (next run re-populates from image)
clean-nix-store:
	podman volume rm $(NIX_VOLUME)
