#!/usr/bin/env bash
set -euo pipefail
plugin_root=$(cd "$(dirname "$0")/.." && pwd)
export OMARCHY_PATH=/tmp/gaugedb-ci-host
git clone --filter=blob:none --no-checkout https://github.com/omacom/omarchy.git "$OMARCHY_PATH"
git -C "$OMARCHY_PATH" checkout 09f16de292febfc76225dee11ffa64497fc6f30d
# This pinned host predates Qt 6.12's Color type. Match the documented VM-only
# compatibility pin, in the disposable host checkout only; never patch a user's shell.
find "$OMARCHY_PATH/shell" -name '*.qml' -exec sed -i 's/^import QtQuick$/import QtQuick 6.11/' {} +
export XDG_RUNTIME_DIR=/tmp/gaugedb-ci-runtime
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
weston --backend=headless --socket=wayland-gaugedb --idle-time=0 --renderer=pixman > /tmp/gaugedb-weston.log 2>&1 &
compositor=$!
trap 'kill "$compositor" 2>/dev/null || true' EXIT
for attempt in {1..100}; do
  [[ ! -S "$XDG_RUNTIME_DIR/wayland-gaugedb" ]] || break
  sleep 0.1
done
[[ -S "$XDG_RUNTIME_DIR/wayland-gaugedb" ]] || { cat /tmp/gaugedb-weston.log; exit 1; }
export WAYLAND_DISPLAY=wayland-gaugedb GAUGEDB_WAYLAND_RUNTIME="$XDG_RUNTIME_DIR"
export QT_QPA_PLATFORM=wayland QT_QUICK_BACKEND=software
bash "$plugin_root/scripts/release-checks.sh"
