IMAGE_NAME := my-opencode

SHELL := /bin/bash
ROOT_PATH = ${OPENCODE_TOOLS_DIR}

.PHONY: shell build update run

shell:
	nix develop .

## Build the custom OpenCode image
build:
	cd ${ROOT_PATH} && podman build -t $(IMAGE_NAME):latest .

## Force rebuild without cache
update:
	cd ${ROOT_PATH} && podman build --no-cache -t $(IMAGE_NAME):latest .

## Run OpenCode in the given WORKDIR (defaults to requiring explicit WORKDIR)
run: build
ifndef WORKDIR
	$(error WORKDIR is not set. Usage: make run WORKDIR=~/src/my-project)
endif
	mkdir -p ~/.opencode/config ~/.opencode/data
	podman run -it --rm --name opencode-$(notdir $(WORKDIR)) \
		--security-opt no-new-privileges:true \
		-e XDG_CONFIG_HOME=/root/.config \
		-e XDG_DATA_HOME=/root/.local/share \
		-e OPENCODE_CONFIG_DIR=/root/.config/opencode \
		-v ~/.opencode/config:/root/.config/opencode:Z \
		-v ~/.opencode/data:/root/.local/share/opencode:Z \
		-v $(WORKDIR):/workspace:Z \
		$(IMAGE_NAME):latest
