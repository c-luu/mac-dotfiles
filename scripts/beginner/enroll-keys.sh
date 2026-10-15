#!/bin/bash
# Enroll explicitly selected passphrase-protected keys in Apple's agent/Keychain.
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
    "${MAC_DOTFILES_TEST_SSH_ADD:-/usr/bin/ssh-add}" --apple-use-keychain "$key"
done
