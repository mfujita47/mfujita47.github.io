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
  python3 - "$ACCOUNT" "$TODOS_PATH" << 'PY'
import json, pathlib, subprocess, sys

account, todos_path = sys.argv[1], pathlib.Path(sys.argv[2])
out = subprocess.check_output(
    ["gog", "--readonly", "--account", account, "tasks", "list", "@default",
     "--all", "--max", "100", "--show-completed", "--show-hidden", "--json", "--no-input"],
    text=True,
)
tasks = json.loads(out).get("tasks", [])
gh = [t for t in tasks if "mfujita47.github.io/redirect.html?cmd=" in (t.get("notes") or "")]
cf = [t for t in tasks if "mfujita47.cloudfree.jp/redirect.html?cmd=" in (t.get("notes") or "")]
print(f"=== Google Tasks (redirect.html?cmd=) ===")
print(f"  github.io    : {len(gh)} tasks (needsAction: {sum(1 for t in gh if t.get('status')=='needsAction')}, completed: {sum(1 for t in gh if t.get('status')=='completed')})")
print(f"  cloudfree.jp : {len(cf)} tasks (needsAction: {sum(1 for t in cf if t.get('status')=='needsAction')}, completed: {sum(1 for t in cf if t.get('status')=='completed')})")
print(f"=== TODOS.md (redirect.html?cmd=) ===")
for idx, line in enumerate(todos_path.read_text(encoding="utf-8").splitlines(), 1):
    if "redirect.html?cmd=" in line:
        print(f"  {idx}:{line}")
PY
  exit 0
else
  echo "Usage: $0 {github|cloudfree|rollback|status}" >&2
  exit 1
fi

echo "Switching redirect URLs: ${FROM_HOST} -> ${TO_HOST}"

python3 - "$ACCOUNT" "$FROM_HOST" "$TO_HOST" << 'PY'
import concurrent.futures, json, subprocess, sys

account, from_host, to_host = sys.argv[1], sys.argv[2], sys.argv[3]
old_sub = f"{from_host}/redirect.html?cmd="
new_sub = f"{to_host}/redirect.html?cmd="

out = subprocess.check_output(
    ["gog", "--readonly", "--account", account, "tasks", "list", "@default",
     "--all", "--max", "100", "--show-completed", "--show-hidden", "--json", "--no-input"],
    text=True,
)
tasks = json.loads(out).get("tasks", [])
targets = [t for t in tasks if old_sub in (t.get("notes") or "")]
print(f"  Found {len(targets)} Google Tasks to update...")

def update_one(t):
    tid = t["id"]
    title = t.get("title", "")
    status = t.get("status", "")
    new_notes = (t.get("notes") or "").replace(old_sub, new_sub)
    subprocess.run(
        ["gog", "--account", account, "tasks", "update", "@default", tid,
         "--notes", new_notes, "--json", "--no-input"],
        check=True,
        stdout=subprocess.DEVNULL,
    )
    return f"  Updated [{status}] {title} ({tid})"

with concurrent.futures.ThreadPoolExecutor(max_workers=8) as ex:
    for msg in ex.map(update_one, targets):
        print(msg)
PY

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
