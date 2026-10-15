#!/bin/bash
# Internal helpers; no installer, credential, or account operations.
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SOURCE=$(cd "$SCRIPT_DIR/.." && pwd)
CHECKOUT=$SOURCE
CONFIG=''
DESTINATION=''
SSH_CONFIG=''
EXPLICIT_SSH_CONFIG=0
SELECTED_REPOSITORY=''
MODE=deployed
CHEZMOI=${CHEZMOI:-chezmoi}
FAILED=0
report() { printf '%s: %s\n' "$1" "$2"; }
problem() { report "$1" "$2"; FAILED=1; }
usage() {
    printf '%s\n' 'Options: --preflight | --publication-only; --source PATH; --config PATH; --destination PATH; --ssh-config PATH; --repository PATH; --checkout PATH'
}
while (($#)); do
    case $1 in
        --preflight) MODE=preflight; shift ;;
        --publication-only) MODE=publication; shift ;;
        --source|--config|--destination|--ssh-config|--repository|--checkout)
            (($# >= 2)) || { usage >&2; exit 2; }
            case $1 in
                --source) SOURCE=$2 ;; --config) CONFIG=$2 ;; --destination) DESTINATION=$2 ;;
                --ssh-config) SSH_CONFIG=$2; EXPLICIT_SSH_CONFIG=1 ;; --repository) SELECTED_REPOSITORY=$2 ;; --checkout) CHECKOUT=$2 ;;
            esac
            shift 2 ;;
        --help) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done
umask 077
SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/mac-dotfiles-check.XXXXXX")
SCRATCH=$(cd "$SCRATCH" && pwd -P)
trap 'rm -rf "$SCRATCH"' EXIT
CM_ARGS=(--source "$SOURCE" --cache "$SCRATCH/cache" --persistent-state "$SCRATCH/state.db" --no-tty)
[[ -z $CONFIG ]] || CM_ARGS+=(--config "$CONFIG")
[[ -z $DESTINATION ]] || CM_ARGS+=(--destination "$DESTINATION")
cm() { "$CHEZMOI" "${CM_ARGS[@]}" "$@"; }
load_profiles() {
    if ! command -v "$CHEZMOI" >/dev/null 2>&1; then
        problem NOT_PERFORMED 'chezmoi is unavailable; install dependencies explicitly'; return 1
    fi
    if ! cm execute-template '{{ includeTemplate ".chezmoitemplates/profile-records" . }}' > "$SCRATCH/profiles" 2> "$SCRATCH/render-errors"; then
        problem FAIL 'local profiles or author source entries are invalid; review local config and source entries'; return 1
    fi
    DESTINATION=$(cm execute-template '{{ .chezmoi.destDir }}' 2> "$SCRATCH/render-errors") || { problem NOT_PERFORMED 'chezmoi location metadata could not be read'; return 1; }
    [[ -n $DESTINATION ]] || { problem NOT_PERFORMED 'chezmoi destination is empty'; return 1; }
    PROFILE_HOME=$(cm execute-template '{{ .chezmoi.homeDir }}' 2> "$SCRATCH/render-errors") || { problem NOT_PERFORMED 'chezmoi location metadata could not be read'; return 1; }
    report PASS 'profile definitions and author source entries'
}
check_mode() {
    local file=$1 expected=$2 actual
    if [[ ! -e $file || -L $file ]]; then problem FAIL "missing or symlinked managed path: $file"; return; fi
    actual=$(/usr/bin/stat -f '%OLp' "$file" 2>/dev/null) || { problem NOT_PERFORMED 'file mode inspection failed'; return; }
    [[ $actual == "$expected" || ( $expected == 600 && $actual == 400 ) ]] || problem FAIL "permissions require $expected (or read-only 400 for private files): $file"
}
