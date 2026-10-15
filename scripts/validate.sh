#!/bin/bash
source "$(dirname "$0")/common.sh" "$@"
source "$SCRIPT_DIR/ssh-checks.sh"
source "$SCRIPT_DIR/git-checks.sh"
source "$SCRIPT_DIR/publication-checks.sh"
for dep in git /bin/zsh /usr/bin/ssh; do
    command -v "$dep" >/dev/null 2>&1 || problem NOT_PERFORMED "dependency unavailable: $dep"
done
if [[ $MODE != publication ]]; then
    command -v brew >/dev/null 2>&1 || problem NOT_PERFORMED 'Homebrew unavailable; follow explicit bootstrap instructions'
    if load_profiles; then
        if [[ $MODE == deployed ]]; then
            [[ -n $SSH_CONFIG ]] || SSH_CONFIG="$DESTINATION/.ssh/config"
            [[ -f $SSH_CONFIG ]] || problem FAIL 'SSH entrypoint missing; integrate the managed include explicitly'
            [[ -f "$DESTINATION/.gitconfig" || -f "$DESTINATION/.config/git/config" ]] || problem FAIL 'Git entrypoint missing; integrate the managed include explicitly'
            check_mode "$DESTINATION/.ssh" 700
            check_mode "$DESTINATION/.ssh/config.d" 700
            check_mode "$DESTINATION/.ssh/config.d/mac-dotfiles.conf" 600
            check_mode "$DESTINATION/.config/git/mac-dotfiles.inc" 600
            while IFS=$'\t' read -r kind id name email alias host port user key account; do
                [[ $kind == P ]] || continue
                check_mode "$DESTINATION/.config/git/$id.inc" 600
                if [[ ! -f $key ]]; then problem CREDENTIAL_MISSING "provision the existing key reference separately: $key"; else check_mode "$key" 600; fi
            done < "$SCRATCH/profiles"
            check_ssh
            check_git
        fi
    fi
fi
check_publication
if ((FAILED)); then report FAIL 'validation incomplete or failed; no repairs performed'; exit 1; fi
report PASS 'requested local checks completed; this is not proof of publication safety'
