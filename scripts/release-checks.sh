#!/usr/bin/env bash
# Run on Linux with the official pinned host and an existing Wayland session.
set -euo pipefail
plugin_root=$(cd "$(dirname "$0")/.." && pwd)
: "${OMARCHY_PATH:?Set OMARCHY_PATH to the official Omarchy checkout}"
bash "$OMARCHY_PATH/bin/omarchy-plugin-validate" "$plugin_root"
bash "$plugin_root/scripts/lint-qml.sh"
python3 -B "$plugin_root/tests/public-fetch.test.py"
bash "$plugin_root/tests/clipboard-helper.test.sh"
bash "$plugin_root/scripts/test-clipboard-input.sh"
bash "$plugin_root/scripts/test-notification-privacy.sh"
bash "$plugin_root/scripts/native-smoke.sh"
