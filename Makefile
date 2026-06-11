IMAGE_NAME := ai-agent
NIX_VOLUME := agent-nix-store
PNPM_VOLUME := agent-pnpm-store
WORKDIR_HASH := $(shell echo -n "$(WORKDIR)" | shasum | cut -c1-8)
CONTAINER_NAME := agent-$(notdir $(WORKDIR))-$(WORKDIR_HASH)
# Secrets loaded via `agentsbox load-secret`. Names are prefixed with either this
# project's workdir hash (agent-<hash>-<name>, mounted only here) or "global"
# (agent-global-<name>, mounted everywhere); the mount target is stored in the
# agents.target label. (`podman secret ls` has no label filter, so we match by
# name prefix, then read the target via inspect.) Project secrets are listed
# first so that if a project and a global secret share a target, the project one
# wins and the duplicate is skipped (podman rejects two mounts at one path).
# NOTE: avoid `case`/`)` and any unbalanced paren in this $(shell ...) — make
# does paren-matching and an unbalanced `)` truncates the command. The grep is
# the seen-target dedup (paren-free).
SECRET_FLAGS := $(shell { \
		podman secret ls --format '{{.Name}}' 2>/dev/null | grep "^agent-$(WORKDIR_HASH)-"; \
		podman secret ls --format '{{.Name}}' 2>/dev/null | grep "^agent-global-"; \
	} | while read -r n; do \
		t=$$(podman secret inspect "$$n" --format '{{index .Spec.Labels "agents.target"}}' 2>/dev/null); \
		[ -z "$$t" ] && continue; \
		printf '%s' "$$seen" | grep -qF " $$t " && continue; \
		seen="$$seen $$t "; \
		printf -- '--secret %s,target=%s,mode=0400 ' "$$n" "$$t"; \
	done)

SHELL := /usr/bin/env bash
ROOT_PATH = ${AGENTS_TOOLS_DIR}

# A2A agent alias other containers address us by (default: workdir basename).
# `agentsbox enter --a2a` passes A2A=1 and AGENT_NAME explicitly.
AGENT_NAME ?= $(notdir $(WORKDIR))

.PHONY: shell build update run clean-nix-store clean-pnpm-store doctor

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
		-v ${ROOT_PATH}/zellij-config.kdl:/root/.config/zellij/config.kdl:Z,ro \
		-v ~/.agents:/root/.agents:Z \
		-v ~/.opencode/config:/root/.config/opencode:Z \
		-v ~/.opencode/data:/root/.local/share/opencode:Z \
		-p 4096 \
		$(if $(AUTH),-p 1455:1455) \
		$(if $(A2A),--network agentsbox-net --network-alias $(AGENT_NAME)) \
		$(if $(A2A),-e A2A_ENABLED=1 -e AGENT_NAME=$(AGENT_NAME)) \
		-v ~/.claude:/root/.claude:Z \
		-v ~/.claude.json:/root/.claude.json:Z \
		-v ~/.codex:/root/.codex:Z \
		-v ~/.config/codex:/root/.config/codex:Z \
		-v ~/.local/share/codex:/root/.local/share/codex:Z \
		-v $(WORKDIR):/workspace:Z \
		$(SECRET_FLAGS) \
		$(IMAGE_NAME):latest

## Check host environment for required tooling
doctor:
	@./bin/doctor

## Remove the persistent Nix store volume (next run re-populates from image)
clean-nix-store:
	podman volume rm $(NIX_VOLUME)

## Remove the persistent pnpm store volume (next run re-populates from image)
clean-pnpm-store:
	podman volume rm $(PNPM_VOLUME)
