#!/bin/bash
# Interactive first connections: retain normal host verification and prompts.
set -euo pipefail
if (($# == 0)); then
    printf 'Usage: %s SSH_ALIAS [SSH_ALIAS ...]\n' "$0" >&2
    exit 2
fi
for alias in "$@"; do
    [[ $alias =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] || {
        printf 'Invalid SSH alias: %s\n' "$alias" >&2
        exit 2
    }
done
for alias in "$@"; do
    printf '\nConnecting to %s; review the fingerprint and account greeting.\n' "$alias"
    status=0
    /usr/bin/ssh -T -o StrictHostKeyChecking=ask "git@$alias" || status=$?
    # GitHub returns 1 on successful authentication because it offers no shell.
    # Print the status without treating it as proof of authentication success.
    printf 'SSH exit status for %s: %s\n' "$alias" "$status"
    if ((status != 0 && status != 1)); then
        exit "$status"
    fi
done
