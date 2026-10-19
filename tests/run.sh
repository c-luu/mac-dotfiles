#!/bin/bash
set -euo pipefail
REPO=$(cd "$(dirname "$0")/.." && pwd)
for script in "$REPO"/scripts/*.sh "$REPO"/scripts/beginner/*.sh "$REPO"/tests/*.sh; do /bin/bash -n "$script"; done
/bin/zsh -n "$REPO/scripts/ssh-safe.zsh"
for test in profiles git ssh validation publication connectivity integration source-publication beginner history guide setup export workspace; do
    printf 'Running %s fixtures\n' "$test"
    /bin/bash "$REPO/tests/$test.sh"
done
printf 'PASS: all fixture suites and shell syntax checks\n'
