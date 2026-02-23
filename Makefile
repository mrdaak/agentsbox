SHELL := /bin/bash
ROOT_PATH = ${OPENCODE_TOOLS_DIR}

shell:
	nix develop .

build:
	# Note: Run 'podman pull ghcr.io/anomalyco/opencode:latest' occasionally for updates
	cd ${ROOT_PATH} && podman build -t my-opencode:latest .

run: build
ifndef WORKDIR
	$(error WORKDIR is not set. Usage: make run WORKDIR=~/src/my-project)
endif
	mkdir -p ~/.opencode/config ~/.opencode/data
	podman run -it --rm --name opencode-$(notdir $(WORKDIR)) \
		-v ~/.opencode/config:/root/.config/opencode \
		-v ~/.opencode/data:/root/.local/share/opencode \
		-v $(WORKDIR):/workspace \
		my-opencode:latest

.PHONY: shell build run
