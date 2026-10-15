#!/bin/bash
# Optional local search terms are never embedded in public source or diagnostics.
set -euo pipefail
if (($# != 1)); then printf 'Usage: %s TERMS_FILE_OUTSIDE_CHECKOUT\n' "$0" >&2; exit 2; fi
root=$(cd "$(dirname "$0")/.." && pwd)
terms=$(cd "$(dirname "$1")" && pwd -P)/$(basename "$1")
[[ -f $terms && ! -L $terms && -s $terms ]] || { printf 'Terms must be a nonempty regular file\n' >&2; exit 2; }
case $terms in "$root"/*) printf 'Keep personal search terms outside this checkout\n' >&2; exit 2 ;; esac
if /usr/bin/grep -q '^[[:space:]]*$' "$terms"; then printf 'Remove blank search terms\n' >&2; exit 2; fi
failed=0
while IFS= read -r -d '' file; do
    [[ -f "$root/$file" && ! -L "$root/$file" ]] || continue
    rc=0
    /usr/bin/grep -qiF -f "$terms" -- "$root/$file" || rc=$?
    case $rc in
        0) printf 'FAIL: local privacy term matched in %s\n' "$file" >&2; failed=1 ;;
        1) ;;
        *) printf 'FAIL: privacy search could not inspect %s\n' "$file" >&2; failed=1 ;;
    esac
done < <(git -C "$root" ls-files --cached --others --exclude-standard -z)
((failed == 0)) || exit 1
printf 'PASS: local terms absent from intended tracked and new source; manual review still required\n'
