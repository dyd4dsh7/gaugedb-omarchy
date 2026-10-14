#!/usr/bin/env bash
# Linux development check. Never points the plugin at a user's real state.
set -euo pipefail
umask 022
plugin_root=$(cd "$(dirname "$0")/.." && pwd)
: "${OMARCHY_PATH:?Set OMARCHY_PATH to the official Omarchy checkout}"
test_root=$(mktemp -d /tmp/gaugedb-native.XXXXXX)
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/config" "$test_root/runtime" "$test_root/state" "$test_root/imports"
chmod 700 "$test_root/runtime"
mkdir "$test_root/config/plugin"
for file in BarWidget.qml Panel.qml ClipboardField.qml ClipboardPaste.qml PublicRequest.qml WatchService.qml PriceHistory.qml BrandMark.qml Model.js Store.js Countries.js Watch.js History.js; do
  cp "$plugin_root/$file" "$test_root/config/plugin/$file"
done
mkdir "$test_root/config/plugin/scripts"
cp "$plugin_root/scripts/clipboard-paste.sh" "$plugin_root/scripts/public-fetch.py" "$test_root/config/plugin/scripts/"
cp -R "$plugin_root/assets" "$test_root/config/plugin/assets"
sed 's|import "../" as Plugin|import "./plugin" as Plugin|' "$plugin_root/tests/native-smoke.qml" > "$test_root/config/shell.qml"
ln -s "$OMARCHY_PATH/shell" "$test_root/imports/qs"
export QML_IMPORT_PATH="$test_root/imports${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
export XDG_RUNTIME_DIR="${GAUGEDB_WAYLAND_RUNTIME:-$test_root/runtime}"
export XDG_STATE_HOME="$test_root/state" XDG_CONFIG_HOME="$test_root/config"
export GAUGEDB_NATIVE_TEST=1
mkdir "$test_root/bin"
cat > "$test_root/bin/notify-send" <<'PYNOTIFY'
#!/usr/bin/env python3
import json, os, sys
with open(os.environ["GAUGEDB_NOTIFICATION_CAPTURE"], "w") as output:
  json.dump(sys.argv[1:], output)
PYNOTIFY
chmod 700 "$test_root/bin/notify-send"
export PATH="$test_root/bin:$PATH"
export GAUGEDB_NOTIFICATION_CAPTURE="$test_root/notification.json"
export GAUGEDB_PUBLIC_PROVIDER="$plugin_root/tests/public-request-fixture.py"
for mode in write read corrupt unsafe network clipboard features; do
  export GAUGEDB_TEST_MODE="$mode"
  # Simulate an earlier permissive installation; the plugin must repair metadata.
  if [[ $mode == read ]]; then chmod 755 "$test_root/state/gaugedb-omarchy"; chmod 644 "$test_root/state/gaugedb-omarchy/state.json"; fi
  if [[ $mode == unsafe ]]; then
    mv "$test_root/state/gaugedb-omarchy" "$test_root/unsafe-canary"
    ln -s "$test_root/unsafe-canary" "$test_root/state/gaugedb-omarchy"
  fi
  if [[ $mode == network ]]; then rm "$test_root/state/gaugedb-omarchy"; fi
  if [[ $mode == corrupt ]]; then printf '{invalid' > "$test_root/state/gaugedb-omarchy/state.json"; fi
  timeout 20s quickshell --no-color -p "$test_root/config" > "$test_root/$mode.log" 2>&1 || { cat "$test_root/$mode.log"; exit 1; }
  if ! grep -q 'GAUGEDB_NATIVE_PASS:' "$test_root/$mode.log" || grep -Eq 'GAUGEDB_NATIVE_FAIL:|ReferenceError|TypeError|Cannot read property|Binding loop|Required property .* was not initialized|config/plugin/.*Unable to assign' "$test_root/$mode.log"; then cat "$test_root/$mode.log"; exit 1; fi
  if [[ $mode == write ]]; then jq -e '.country == "US" and .favourites[0].id == "steam:620"' "$test_root/state/gaugedb-omarchy/state.json" >/dev/null; fi
  if [[ $mode == corrupt ]]; then [[ $(cat "$test_root/state/gaugedb-omarchy/state.json") == '{invalid' ]]; fi
  if [[ $mode == unsafe ]]; then
    [[ $(cat "$test_root/unsafe-canary/state.json") == '{invalid' ]]
  else
    [[ $(stat -c %a "$test_root/state/gaugedb-omarchy") == 700 ]]
    [[ $(stat -c %a "$test_root/state/gaugedb-omarchy/state.json") == 600 ]]
  fi
  if [[ $mode == features ]]; then
    python3 - "$test_root/notification.json" <<'PYPRIVACY'
import json, sys
args=json.load(open(sys.argv[1]))
assert args == ["--app-name=GaugeDB", "GaugeDB price watch", "A watched price fell. Open GaugeDB to review saved prices; check Steam before buying."]
assert all(secret not in " ".join(args) for secret in ["Portal", "620", "499", "NZD", "76561197960265729"])
print("NOTIFICATION_PRIVACY_PASS: captured argv contains no watch details")
PYPRIVACY
  fi
  grep 'GAUGEDB_NATIVE_PASS:' "$test_root/$mode.log"
done
