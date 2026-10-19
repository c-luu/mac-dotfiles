#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
grep -Fq '../mac-dotfiles' "$root/README.md"
grep -Fq 'homeops' "$root/README.md"
if grep -REn '/Users/[^` ]+' "$root/README.md" "$root/AGENTS.md" >/dev/null; then
    printf 'FAIL: repository documentation contains a machine-specific absolute path\n' >&2
    exit 1
fi
printf 'PASS: workspace documentation uses portable repository references\n'
