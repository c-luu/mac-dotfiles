#!/bin/bash
# Sourced by offline validation.
check_ssh() {
    local kind id name email alias host port user key account effective keychain
    local -a config_graph ssh_args
    [[ -f $SSH_CONFIG ]] || return
    config_graph=("$SSH_CONFIG")
    # With explicit --ssh-config, -F intentionally uses only that graph (fixtures).
    if [[ ${EXPLICIT_SSH_CONFIG:-0} == 0 && -f /etc/ssh/ssh_config ]]; then
        config_graph+=(/etc/ssh/ssh_config)
    fi
    printf 'Include "%s"\nHost *\n' "$SSH_CONFIG" > "$SCRATCH/ssh-wrapper"
    if ((${#config_graph[@]} == 2)); then printf 'Include /etc/ssh/ssh_config\n' >> "$SCRATCH/ssh-wrapper"; fi
    while IFS=$'\t' read -r kind id name email alias host port user key account; do
        [[ $kind == P ]] || continue
        if ! keychain=$(/bin/zsh -f "$SCRIPT_DIR/ssh-safe.zsh" "$alias" "$PROFILE_HOME" "${config_graph[@]}" 2>/dev/null); then
            problem NOT_PERFORMED "unsafe or unsupported SSH configuration graph for profile $id; review includes and executable directives"
            continue
        fi
        [[ $keychain == yes ]] || problem FAIL "Keychain use is not enabled for profile $id"
        effective="$SCRATCH/ssh-$id"
        if ! /usr/bin/ssh -G -F "$SCRATCH/ssh-wrapper" "$alias" > "$effective" 2> "$SCRATCH/ssh-errors"; then
            problem NOT_PERFORMED "SSH parser rejected configuration for profile $id"; continue
        fi
        for expected in "hostname $host" "port $port" "user $user" 'identitiesonly yes' 'addkeystoagent true'; do
            /usr/bin/grep -qxF "$expected" "$effective" || problem FAIL "SSH host/port/user/agent/identity restriction mismatch for profile $id"
        done
        if [[ $(/usr/bin/grep -c '^identityfile ' "$effective") != 1 ]] || ! /usr/bin/grep -qxF "identityfile $key" "$effective"; then
            problem FAIL "SSH key selection is incorrect or ambiguous for profile $id"
        fi
    done < "$SCRATCH/profiles"
}
