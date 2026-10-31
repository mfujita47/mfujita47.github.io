#!/usr/bin/env bash
# Switch Google Tasks and TODOS.md redirect.html URLs between GitHub Pages and Cloudfree (for rollback).
# Usage:
#   switch_redirect_url.sh github     # Use https://mfujita47.github.io/redirect.html
#   switch_redirect_url.sh cloudfree  # Rollback to https://mfujita47.cloudfree.jp/redirect.html
#   switch_redirect_url.sh status     # Check current redirect URL host in Google Tasks and TODOS.md
set -euo pipefail

ACCOUNT="mfujita47@gmail.com"
TODOS_PATH="/mnt/cloud/dropbox-mitsugu/ChangeLog/TODOS.md"

MODE="${1:-}"
if [[ "$MODE" == "github" ]]; then
  FROM_HOST="mfujita47.cloudfree.jp"
  TO_HOST="mfujita47.github.io"
elif [[ "$MODE" == "cloudfree" || "$MODE" == "rollback" ]]; then
  FROM_HOST="mfujita47.github.io"
  TO_HOST="mfujita47.cloudfree.jp"
elif [[ "$MODE" == "status" ]]; then
  echo "=== Google Tasks (redirect.html?cmd=) ==="
  gog --readonly --account "$ACCOUNT" tasks list @default --show-completed=false --all --max 100 --json --no-input \
    | jq -r '.tasks[] | select((.notes // "") | contains("/redirect.html?cmd=")) | "  \(.id) | \(.title) -> \(.notes)"'
  echo "=== TODOS.md (redirect.html?cmd=) ==="
  grep -n "redirect.html?cmd=" "$TODOS_PATH" | sed 's/^/  /' || true
  exit 0
else
  echo "Usage: $0 {github|cloudfree|rollback|status}" >&2
  exit 1
fi

echo "Switching redirect URLs: ${FROM_HOST} -> ${TO_HOST}"

mapfile -t TASKS < <(
  gog --readonly --account "$ACCOUNT" tasks list @default --show-completed=false --all --max 100 --json --no-input \
    | jq -c ".tasks[] | select((.notes // \"\") | contains(\"${FROM_HOST}/redirect.html?cmd=\")) | {id, title, notes}"
)

for item in "${TASKS[@]}"; do
  [[ -z "$item" ]] && continue
  id=$(echo "$item" | jq -r '.id')
  title=$(echo "$item" | jq -r '.title')
  old_notes=$(echo "$item" | jq -r '.notes')
  new_notes="${old_notes//${FROM_HOST}\/redirect.html?cmd=/${TO_HOST}/redirect.html?cmd=}"
  gog --account "$ACCOUNT" tasks update @default "$id" --notes "$new_notes" --json --no-input >/dev/null
  echo "  Updated Google Task: $title ($id)"
done

if [[ -f "$TODOS_PATH" ]] && grep -q "${FROM_HOST}/redirect.html?cmd=" "$TODOS_PATH"; then
  python3 - "$TODOS_PATH" "$FROM_HOST" "$TO_HOST" << 'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
raw = p.read_bytes()
old_b = f"{sys.argv[2]}/redirect.html?cmd=".encode("utf-8")
new_b = f"{sys.argv[3]}/redirect.html?cmd=".encode("utf-8")
if old_b in raw:
    p.write_bytes(raw.replace(old_b, new_b))
    print(f"  Updated {p}")
PY
fi

echo "Done."
