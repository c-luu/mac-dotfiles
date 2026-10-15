#!/bin/bash
# Only change explicitly selected existing private-key paths.
set -euo pipefail
if (($# == 0)); then
    printf 'Usage: %s PRIVATE_KEY [PRIVATE_KEY ...]\n' "$0" >&2
    exit 2
fi
for key in "$@"; do
    [[ -f $key && ! -L $key && $key != *.pub ]] || {
        printf 'Expected an existing, non-symlink private-key path: %s\n' "$key" >&2
        exit 1
    }
done
for key in "$@"; do
    chmod 600 "$key"
done
