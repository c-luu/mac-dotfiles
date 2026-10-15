#!/bin/bash
set -euo pipefail
REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CHEZMOI=${CHEZMOI:-chezmoi}
FIXTURE=$(mktemp -d "${TMPDIR:-/tmp}/mac-dotfiles-test.XXXXXX")
FIXTURE=$(cd "$FIXTURE" && pwd -P)
trap 'rm -rf "$FIXTURE"' EXIT
mkdir -p "$FIXTURE/source" "$FIXTURE/target" "$FIXTURE/cache"
cp -R "$REPO/home" "$FIXTURE/source/"
cp "$REPO/.chezmoiroot" "$FIXTURE/source/"
cm() { "$CHEZMOI" --source "$FIXTURE/source" --destination "$FIXTURE/target" --config "$FIXTURE/config.toml" --cache "$FIXTURE/cache" --persistent-state "$FIXTURE/state.db" "$@"; }
profile() {
    local id=$1 alias=$2 host=$3 port=${4:-22}
    cat >> "$FIXTURE/config.toml" <<TOML
[data.profiles.$id]
authorName = 'Example "$id" Author & Team'
authorEmail = '$id@example.com'
repositoryRoots = ['$FIXTURE/repos/$id']
sshAlias = '$alias'
hostname = '$host'
port = $port
sshUser = 'git'
identityFile = '$FIXTURE/keys/$id'
expectedAccount = '$id-example'
TOML
}
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
expect_failure() { if "$@" > "$FIXTURE/negative.out" 2>&1; then fail "expected failure: $*"; fi; }
