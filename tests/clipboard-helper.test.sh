#!/usr/bin/env bash
set -euo pipefail
plugin_root=$(cd "$(dirname "$0")/.." && pwd)
test_root=$(mktemp -d /tmp/gaugedb-clipboard-test.XXXXXX)
trap 'rm -rf "$test_root"' EXIT
mkdir "$test_root/bin"
cat > "$test_root/bin/wl-paste" <<'FIXTURE'
#!/usr/bin/env bash
for arg in "$@"; do
  if [[ $arg == --list-types ]]; then printf 'text/plain;charset=utf-8\n'; exit; fi
done
case $GAUGEDB_CLIP_TEST in
  normal) printf 'Portal 2';;
  unicode) printf '日本語';;
  oversized) head -c 8192 /dev/zero | tr '\0' x;;
  stream) while :; do printf 'x'; sleep 0.05; done;;
  nul) printf 'A\0B';;
  invalid) printf '\377';;
  primary) [[ " $* " == *' --primary '* ]]; printf 'primary';;
esac
FIXTURE
chmod +x "$test_root/bin/wl-paste"
export PATH="$test_root/bin:$PATH"
for mode in normal unicode primary; do
  export GAUGEDB_CLIP_TEST=$mode
  timeout --signal=TERM --kill-after=0.2s 1s bash "$plugin_root/scripts/clipboard-paste.sh" "$mode" > "$test_root/out"
  case $mode in normal) [[ $(cat "$test_root/out") == 'Portal 2' ]];; unicode) [[ $(cat "$test_root/out") == '日本語' ]];; primary) [[ $(cat "$test_root/out") == 'primary' ]];; esac
done
for mode in oversized stream invalid nul; do
  export GAUGEDB_CLIP_TEST=$mode
  if timeout --signal=TERM --kill-after=0.2s 1s bash "$plugin_root/scripts/clipboard-paste.sh" clipboard > "$test_root/out" 2> "$test_root/error"; then echo "Unsafe clipboard accepted: $mode" >&2; exit 1; fi
  [[ $(wc -c < "$test_root/out") == 0 ]]
done
echo 'CLIPBOARD_HELPER_PASS: normal, Unicode, primary, oversized, endless stream invalid UTF-8 and NUL'
