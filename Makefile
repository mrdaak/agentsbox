IMAGE_NAME := ai-agent
NIX_VOLUME := agent-nix-store
PNPM_VOLUME := agent-pnpm-store
WORKDIR_HASH := $(shell echo -n "$(WORKDIR)" | shasum | cut -c1-8)
CONTAINER_NAME := agent-$(notdir $(WORKDIR))-$(WORKDIR_HASH)
NPMRC_SECRET := $(shell podman secret exists npmrc 2>/dev/null && echo "--secret npmrc,target=/root/.npmrc")

SHELL := /usr/bin/env bash
ROOT_PATH = ${AGENTS_TOOLS_DIR}

.PHONY: shell build update run clean-nix-store clean-pnpm-store

shell:
	nix develop . --extra-experimental-features "nix-command flakes"

## Build the image
build:
	cd ${ROOT_PATH} && podman build -t $(IMAGE_NAME):latest .

## Force rebuild without cache
update:
	cd ${ROOT_PATH} && podman build --no-cache -t $(IMAGE_NAME):latest .

## Run agent in the given WORKDIR (defaults to requiring explicit WORKDIR)
run: build
ifndef WORKDIR
	$(error WORKDIR is not set. Usage: make run AGENT=claude WORKDIR=~/src/my-project)
endif
	mkdir -p ~/.opencode/config ~/.opencode/data ~/.claude ~/.codex ~/.config/codex ~/.local/share/codex ~/.agents/skills
	touch ~/.claude.json
	podman run -it --rm --name $(CONTAINER_NAME) \
		--security-opt no-new-privileges:true \
		-e XDG_CONFIG_HOME=/root/.config \
		-e XDG_DATA_HOME=/root/.local/share \
		-e OPENCODE_CONFIG_DIR=/root/.config/opencode \
		-v $(NIX_VOLUME):/nix \
		-v $(PNPM_VOLUME):/pnpm-store \
		-v ~/.agents:/root/.agents:Z \
		-v ~/.opencode/config:/root/.config/opencode:Z \
		-v ~/.opencode/data:/root/.local/share/opencode:Z \
		-p 4096 \
		$(if $(AUTH),-p 1455:1455) \
		-v ~/.claude:/root/.claude:Z \
		-v ~/.claude.json:/root/.claude.json:Z \
		-v ~/.codex:/root/.codex:Z \
		-v ~/.config/codex:/root/.config/codex:Z \
		-v ~/.local/share/codex:/root/.local/share/codex:Z \
		-v $(WORKDIR):/workspace:Z \
		$(NPMRC_SECRET) \
		$(IMAGE_NAME):latest

## Remove the persistent Nix store volume (next run re-populates from image)
clean-nix-store:
	podman volume rm $(NIX_VOLUME)

## Remove the persistent pnpm store volume (next run re-populates from image)
clean-pnpm-store:
	podman volume rm $(PNPM_VOLUME)
