#!/bin/bash
# Export a reviewed commit's allowlisted blobs, never its Git database or planning.
set -euo pipefail
if (($# != 2)); then printf 'Usage: %s REVIEWED_COMMIT NEW_DESTINATION\n' "$0" >&2; exit 2; fi
root=$(cd "$(dirname "$0")/.." && pwd -P)
revision=$(git -C "$root" rev-parse --verify --end-of-options "$1^{commit}")
[[ -z $(git -C "$root" status --porcelain --untracked-files=all) ]] || { printf 'FAIL: source must be clean and committed before export\n' >&2; exit 1; }
dest_parent=$(cd "$(dirname "$2")" && pwd -P)
name=$(basename "$2")
[[ $name != . && $name != .. && $name != / ]] || { printf 'FAIL: unsafe destination\n' >&2; exit 1; }
destination="$dest_parent/$name"
case $destination in "$root"|"$root"/*) printf 'FAIL: destination must be outside source\n' >&2; exit 1 ;; esac
[[ ! -e $destination && ! -L $destination ]] || { printf 'FAIL: destination must be unused\n' >&2; exit 1; }
scratch=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-export.XXXXXX")
trap 'rm -rf "$scratch"' EXIT
git -C "$root" ls-tree -r -z "$revision" > "$scratch/tree"
# Check all selected paths before making the destination.
selected=0
while IFS= read -r -d '' entry; do
    metadata=${entry%%$'\t'*}; path=${entry#*$'\t'}
    case $path in
        .chezmoiroot|.gitignore|Brewfile|Brewfile.gh|README.md|SECURITY.md|docs/*|examples/*|home/*|scripts/*|tests/*) ;;
        *) continue ;;
    esac
    case $metadata in '100644 blob '*|'100755 blob '*) ;; *) printf 'FAIL: selected source contains a symlink or unsupported entry\n' >&2; exit 1 ;; esac
    selected=$((selected+1))
done < "$scratch/tree"
((selected > 0)) || { printf 'FAIL: no approved source files found\n' >&2; exit 1; }
mkdir "$destination"
while IFS= read -r -d '' entry; do
    metadata=${entry%%$'\t'*}; path=${entry#*$'\t'}
    case $path in
        .chezmoiroot|.gitignore|Brewfile|Brewfile.gh|README.md|SECURITY.md|docs/*|examples/*|home/*|scripts/*|tests/*) ;;
        *) continue ;;
    esac
    object=${metadata##* }
    mkdir -p "$destination/$(dirname "$path")"
    git -C "$root" cat-file blob "$object" > "$destination/$path"
    case $metadata in '100755 '*) chmod 755 "$destination/$path" ;; *) chmod 644 "$destination/$path" ;; esac
done < "$scratch/tree"
printf 'Exported %s files from commit %s to %s\n' "$selected" "$revision" "$destination"
printf 'Review the exported tree, scan it, then initialize fresh history with chosen public metadata. No repository, commit, remote, or push was created.\n'
