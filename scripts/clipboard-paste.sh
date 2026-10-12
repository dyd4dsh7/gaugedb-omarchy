#!/usr/bin/env bash
# Explicit gestures only; external timeout bounds this entire process group.
set -euo pipefail
ulimit -v 65536
selection_args=()
if [[ ${1:-clipboard} == primary ]]; then selection_args+=(--primary); fi
# MIME metadata and encoded payload stay in bounded memory; no clipboard files.
types=$(wl-paste "${selection_args[@]}" --list-types | head -c 4097)
[[ $(printf '%s' "$types" | wc -c) -le 4096 ]] || exit 65
if printf '%s\n' "$types" | grep -qx 'text/plain;charset=utf-8'; then
  mime='text/plain;charset=utf-8'
elif printf '%s\n' "$types" | grep -qx 'text/plain'; then
  mime=text/plain
else
  exit 66
fi
encoded=$(wl-paste "${selection_args[@]}" --no-newline --type "$mime" | head -c 4097 | base64 -w 0) || exit 66
bytes=$(printf '%s' "$encoded" | base64 -d | wc -c)
[[ $bytes -le 4096 ]] || exit 65
without_nul=$(printf '%s' "$encoded" | base64 -d | tr -d '\000' | wc -c)
[[ $bytes == "$without_nul" ]] || exit 65
printf '%s' "$encoded" | base64 -d | iconv -f UTF-8 -t UTF-8 >/dev/null || exit 65
printf '%s' "$encoded" | base64 -d
