#!/usr/bin/env bash
set -euo pipefail
plugin_root=$(cd "$(dirname "$0")/.." && pwd)
test_root=$(mktemp -d /tmp/gaugedb-clipboard-input.XXXXXX)
trap 'rm -rf "$test_root"' EXIT
g++ -fPIC "$plugin_root/tests/clipboard-input.cpp" -o "$test_root/probe" $(pkg-config --cflags --libs Qt6Quick Qt6Gui Qt6Qml Qt6Test)
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software timeout 15s "$test_root/probe" "$plugin_root"
