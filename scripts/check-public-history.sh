#!/bin/bash
# Check every candidate commit, including paths subsequently deleted.
set -euo pipefail
if (($# < 2 || $# > 3)); then
    printf 'Usage: %s BASE CANDIDATE [EXCLUDED_BRANCH]\n' "$0" >&2; exit 2
fi
base=$(git rev-parse --verify "$1^{commit}")
tip=$(git rev-parse --verify "$2^{commit}")
git merge-base --is-ancestor "$base" "$tip" || { printf 'FAIL: candidate does not descend from base\n' >&2; exit 1; }
for commit in $(git rev-list "$tip" "^$base"); do
    while IFS= read -r -d '' path; do
        case $path in
            .chezmoiroot|.gitignore|Brewfile|Brewfile.gh|README.md|SECURITY.md|docs/*|examples/*|home/*|scripts/*|tests/*) ;;
            *) printf 'FAIL: candidate commit changes an unapproved path\n' >&2; exit 1 ;;
        esac
    done < <(git diff-tree --root -m --no-commit-id --name-only -z -r "$commit")
done
if (($# == 3)); then
    for commit in $(git rev-list "$3" "^$base"); do
        if git merge-base --is-ancestor "$commit" "$tip"; then
            printf 'FAIL: excluded history is reachable from candidate\n' >&2; exit 1
        fi
    done
fi
printf 'PASS: candidate history contains only approved implementation paths\n'
