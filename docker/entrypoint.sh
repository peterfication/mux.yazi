#!/usr/bin/env bash
set -euo pipefail

mkdir -p "${YAZI_CONFIG_HOME}" "${YAZI_PLUGINS_DIR}" "${WORKSPACE_DIR}"

if [ ! -e /opt/mux-dev/init.lua ] || [ ! -e /opt/mux-dev/yazi.toml ] || [ ! -e /opt/mux-dev/keymap.toml ]; then
  echo "Expected Yazi dev config in /opt/mux-dev" >&2
  echo "Bind-mount this repository's docker/ directory there before starting the container." >&2
  exit 1
fi

cp /opt/mux-dev/init.lua "${YAZI_CONFIG_HOME}/init.lua"
cp /opt/mux-dev/yazi.toml "${YAZI_CONFIG_HOME}/yazi.toml"
cp /opt/mux-dev/keymap.toml "${YAZI_CONFIG_HOME}/keymap.toml"

if [ ! -e "${WORKSPACE_DIR}/main.lua" ]; then
  echo "Expected plugin source at ${WORKSPACE_DIR}" >&2
  echo "Bind-mount this repository there before starting the container." >&2
  exit 1
fi

rm -rf "${YAZI_PLUGINS_DIR}/mux.yazi"
ln -s "${WORKSPACE_DIR}" "${YAZI_PLUGINS_DIR}/mux.yazi"

exec "$@"
