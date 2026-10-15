#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
guide=${1:-"$root/docs/README-beginner.md"}
awk '
 /^```sh$/ {inside=1; count=0; next}
 /^```$/ && inside {if(count>1) exit 1; inside=0; next}
 inside && NF {count++}
 END {if(inside) exit 1}
' "$guide" || { printf 'FAIL: guide shell blocks must contain one command\n' >&2; exit 1; }
while IFS= read -r path; do
    [[ -f "$root/$path" && -x "$root/$path" ]] || { printf 'FAIL: guide references a missing or nonexecutable script\n' >&2; exit 1; }
done < <(sed -nE 's@^\./(scripts/[A-Za-z0-9_./-]+\.sh).*@\1@p' "$guide")
printf 'PASS: guide commands and executable references\n'
