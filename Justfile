default:
  just --list

# Run all steps from CI
ci: format lint test

# Format all files
format: format-lua format-rest

# Format lua files with stylua
format-lua:
  stylua .

# Format all other files with dprint
format-rest:
  dprint fmt

# Lint lua files with luacheck
lint:
  luacheck .

# Run tests
test:
  lua tests/main_spec.lua

CONTAINER_IMAGE := "mux-yazi-dev"
CONTAINER_VERSION := "v26.1.22"

# Build the podman image with a pinned Yazi version
container_build VERSION=CONTAINER_VERSION:
  podman build --build-arg YAZI_VERSION={{VERSION}} -t {{CONTAINER_IMAGE}}:{{VERSION}} .

# Start an interactive shell with the repo mounted as the live plugin source
container_shell VERSION=CONTAINER_VERSION:
  podman run --rm -it -v {{justfile_directory()}}:/workspace/mux.yazi -v {{justfile_directory()}}/docker:/opt/mux-dev:ro -w /workspace/mux.yazi {{CONTAINER_IMAGE}}:{{VERSION}}

# Start Yazi directly inside the same development container
container_yazi VERSION=CONTAINER_VERSION:
  podman run --rm -it -v {{justfile_directory()}}:/workspace/mux.yazi -v {{justfile_directory()}}/docker:/opt/mux-dev:ro -w /workspace/mux.yazi {{CONTAINER_IMAGE}}:{{VERSION}} yazi

# Build the container with the latest Yazi version
container_build_nightly:
  just container_build VERSION=nightly

# Start an interactive shell with the latest Yazi version
container_shell_nightly:
  just container_shell VERSION=nightly

# Start Yazi directly with the latest version inside the same development container
container_yazi_nightly:
  just container_yazi VERSION=nightly
