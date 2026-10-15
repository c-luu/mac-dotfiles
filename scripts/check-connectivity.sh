#!/bin/bash
source "$(dirname "$0")/common.sh" "$@"
[[ $MODE == deployed ]] || { report FAIL 'connectivity is an explicit network action; validation modes are not accepted'; exit 2; }
load_profiles || exit 1
# APPLE_SSH is a test seam, not a provider/account selector. Default is Apple's SSH.
APPLE_SSH=${MAC_DOTFILES_TEST_SSH:-/usr/bin/ssh}
[[ -n $SSH_CONFIG ]] || SSH_CONFIG="$DESTINATION/.ssh/config"
SSH_ARGS=()
if [[ $EXPLICIT_SSH_CONFIG == 1 || $DESTINATION != "$PROFILE_HOME" ]]; then SSH_ARGS=(-F "$SSH_CONFIG"); fi
while IFS=$'\t' read -r kind id name email alias host port user key account; do
    [[ $kind == P ]] || continue
    rc=0
    # Bash 3.2 treats an empty array as unset under nounset. Expand only if populated.
    # Keep SSH from consuming the remaining profile records on the loop's stdin.
    "$APPLE_SSH" -T ${SSH_ARGS[@]+"${SSH_ARGS[@]}"} -o ConnectTimeout=10 -o ConnectionAttempts=1 -o BatchMode=yes -o StrictHostKeyChecking=yes -o ServerAliveInterval=5 -o ServerAliveCountMax=2 "$alias" < /dev/null > "$SCRATCH/response" 2>&1 || rc=$?
    # Response values are not echoed. Unknown enterprise formats remain inconclusive.
    authenticated=$(sed -n "s/^Hi \([^!]*\)! You've successfully authenticated, but GitHub does not provide shell access\..*$/\1/p" "$SCRATCH/response")
    if [[ -n $authenticated ]]; then
        if [[ $authenticated == "$account" && ( $rc == 0 || $rc == 1 ) ]]; then report PASS "profile $id authenticated as expected (SSH status $rc; shell access denied)"; else problem ACCOUNT_MISMATCH "profile $id authenticated as an unexpected account or returned inconsistent status"; fi
    elif /usr/bin/grep -qiE 'timed out|timeout' "$SCRATCH/response"; then problem TIMEOUT "profile $id connection timed out"
    elif /usr/bin/grep -qiE 'Host key verification failed|REMOTE HOST IDENTIFICATION HAS CHANGED|No .* host key is known' "$SCRATCH/response"; then problem HOST_VERIFICATION "profile $id requires trusted host fingerprint review"
    elif /usr/bin/grep -qiE 'Permission denied|Authentication failed' "$SCRATCH/response"; then problem AUTHENTICATION_FAILED "profile $id did not authenticate"
    else problem INCONCLUSIVE "profile $id response is not recognized (SSH status $rc); inspect manually with normal host verification"
    fi
done < "$SCRATCH/profiles"
exit "$FAILED"
