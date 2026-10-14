#!/usr/bin/env bash
set -euo pipefail
plugin_root=$(cd "$(dirname "$0")/.." && pwd)
test_root=$(mktemp -d /tmp/gaugedb-privacy.XXXXXX)
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$test_root/bin" "$test_root/config/plugin" "$test_root/runtime"
chmod 700 "$test_root/runtime"
for file in WatchService.qml Watch.js Model.js PublicRequest.qml; do cp "$plugin_root/$file" "$test_root/config/plugin/"; done
sed 's|import "../" as Plugin|import "./plugin" as Plugin|' "$plugin_root/tests/notification-privacy.qml" > "$test_root/config/shell.qml"
cat > "$test_root/bin/notify-send" <<'PY'
#!/usr/bin/env python3
import json, os, sys
with open(os.environ['GAUGEDB_NOTIFICATION_CAPTURE'], 'w') as output:
    json.dump(sys.argv[1:], output)
PY
chmod 700 "$test_root/bin/notify-send"
export PATH="$test_root/bin:$PATH"
export GAUGEDB_NOTIFICATION_CAPTURE="$test_root/argv.json"
export GAUGEDB_PUBLIC_PROVIDER="$plugin_root/tests/public-request-fixture.py"
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software XDG_RUNTIME_DIR="$test_root/runtime" timeout 15s quickshell --no-color -p "$test_root/config" > "$test_root/result.log" 2>&1
if ! grep -q 'PRIVACY_PASS:' "$test_root/result.log" || grep -q 'PRIVACY_FAIL:' "$test_root/result.log"; then cat "$test_root/result.log"; exit 1; fi
python3 - "$test_root/argv.json" <<'PY'
import json, sys
args=json.load(open(sys.argv[1]))
assert args == ['--app-name=GaugeDB','GaugeDB price watch','A watched price fell. Open GaugeDB to review saved prices; check Steam before buying.']
assert not any(secret in ' '.join(args) for secret in ['PRIVATE WATCH NAME','620','499','NZD','76561197960265729'])
print('NOTIFICATION_PRIVACY_PASS: actual helper argv contains no watched identifiers or prices')
PY
grep 'PRIVACY_PASS:' "$test_root/result.log"
