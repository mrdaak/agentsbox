IMAGE_NAME := my-opencode
UPSTREAM   := ghcr.io/anomalyco/opencode:latest

SHELL := /bin/bash
ROOT_PATH = ${OPENCODE_TOOLS_DIR}

.PHONY: shell build update run

shell:
	nix develop .

## Build the custom OpenCode image
build:
	cd ${ROOT_PATH} && podman build -t $(IMAGE_NAME):latest .

## Pull latest upstream image and rebuild
update:
	podman pull $(UPSTREAM)
	cd ${ROOT_PATH} && podman build --no-cache -t $(IMAGE_NAME):latest .

## Run OpenCode in the given WORKDIR (defaults to requiring explicit WORKDIR)
run: build
ifndef WORKDIR
	$(error WORKDIR is not set. Usage: make run WORKDIR=~/src/my-project)
endif
	mkdir -p ~/.opencode/config ~/.opencode/data
	podman run -it --rm --name opencode-$(notdir $(WORKDIR)) \
		--security-opt no-new-privileges:true \
		-v ~/.opencode/config:/root/.config/opencode \
		-v ~/.opencode/data:/root/.local/share/opencode \
		-v $(WORKDIR):/workspace \
		$(IMAGE_NAME):latest
