#!/usr/bin/env bash
set -euo pipefail
plugin_root=$(cd "$(dirname "$0")/.." && pwd)
: "${OMARCHY_PATH:?Set OMARCHY_PATH to the official Omarchy checkout}"
lint_bin=${QMLLINT_BIN:-qmllint}
if ! command -v "$lint_bin" >/dev/null && [[ -x /usr/lib/qt6/bin/qmllint ]]; then
  lint_bin=/usr/lib/qt6/bin/qmllint
fi
imports=$(mktemp -d /tmp/gaugedb-qml-imports.XXXXXX)
trap 'rm -rf "$imports"' EXIT
ln -s "$OMARCHY_PATH/shell" "$imports/qs"
if ! "$lint_bin" --max-warnings 0 --json "$imports/report.json" -I "$imports" \
  "$plugin_root/BarWidget.qml" "$plugin_root/Panel.qml" \
  "$plugin_root/ClipboardField.qml" "$plugin_root/ClipboardPaste.qml" "$plugin_root/BrandMark.qml" "$plugin_root/PublicRequest.qml" "$plugin_root/WatchService.qml" "$plugin_root/PriceHistory.qml" "$plugin_root/tests/native-smoke.qml" "$plugin_root/tests/notification-privacy.qml"; then
  jq -r '.files[] | .filename as $file | .warnings[] | "\($file):\(.line):\(.column): \(.message)"' "$imports/report.json"
  exit 1
fi
