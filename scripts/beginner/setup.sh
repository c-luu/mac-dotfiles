#!/bin/bash
# Interactive orchestration only; validators and chezmoi apply never provision keys.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
case ${1:-} in
    --help) printf '%s\n' 'Usage: ./scripts/beginner/setup.sh' 'Interactive setup: packages, backup, Vim profiles, preview/apply, manual includes,' 'per-profile keys and browser registration, validation, optional connections.' 'Blank declines. Enter stop at a prompt or press Control-C to stop.'; exit 0 ;;
    '') ;;
    *) printf 'Unknown option; use --help\n' >&2; exit 2 ;;
esac
[[ $# == 0 ]] || { printf 'Unexpected arguments\n' >&2; exit 2; }
[[ -t 0 && -t 1 ]] || { printf 'Interactive terminal required; no changes made.\n' >&2; exit 2; }
exec 3</dev/tty
umask 077
scratch=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-setup.XXXXXX")
trap 'rm -rf "$scratch"' EXIT
trap 'printf "\nSetup interrupted; completed changes remain. Rerun to inspect and continue.\n" >&2; exit 130' INT
trap 'exit 143' TERM
stop() { printf 'INCOMPLETE: setup stopped; completed changes remain. Rerun to inspect and continue.\n' >&2; exit 1; }
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ask() {
    local answer=''
    printf '\n%s [yes/No/stop] ' "$1"
    read -r -u 3 answer || stop
    case $answer in yes|YES) return 0 ;; stop|STOP) stop ;; *) return 1 ;; esac
}
require() { ask "$1" || stop; }
run() { "$@" 3<&- 4<&-; }
cm_bin=${CHEZMOI:-chezmoi}
keygen=${MAC_DOTFILES_TEST_KEYGEN:-/usr/bin/ssh-keygen}
ssh_bin=${MAC_DOTFILES_TEST_SSH:-/usr/bin/ssh}
validate=${MAC_DOTFILES_TEST_VALIDATE:-"$root/scripts/validate.sh"}
config="$HOME/.config/chezmoi/chezmoi.toml"
cm() { run "$cm_bin" --source "$root" --config "$config" "$@"; }
printf 'Setup uses local profiles outside the checkout. Review docs/README-beginner.md first.\n'
command -v brew >/dev/null 2>&1 || fail 'Homebrew must already be installed and available.'
command -v git >/dev/null 2>&1 || fail 'Git is required to acquire and inspect this checkout.'
if ask 'PACKAGE INSTALLATION: install Brewfile tools with normal Homebrew cleanup (no requested upgrades)?'; then
    run brew bundle install --no-upgrade --file="$root/Brewfile"
else
    printf 'SKIPPED: package installation; required tools must already exist.\n'
fi
command -v "$cm_bin" >/dev/null 2>&1 || fail 'chezmoi is required; install the Brewfile tools first.'
command -v vim >/dev/null 2>&1 || fail 'Vim is required for local editing.'
require 'LOCAL CHANGE: back up existing profile/Git/SSH entrypoints (asks before backup overwrites)?'
run "$root/scripts/beginner/backup-config.sh" < /dev/tty
if [[ ! -e $config && ! -L $config ]]; then
    require 'LOCAL CHANGE: create the local chezmoi config from the generic example?'
    mkdir -p "$(dirname "$config")"
    (set -o noclobber; cat "$root/examples/profiles.toml" > "$config") || fail 'Config path became occupied; review it manually.'
fi
[[ -f $config ]] || fail 'Local config is not a regular file; review the path manually.'
require 'LOCAL CHANGE: open profiles in Vim? Keep only needed profiles and replace every REPLACE_ME.'
run "$root/scripts/beginner/edit-profiles.sh" < /dev/tty
require 'LOCAL CHANGE: initialize chezmoi from these profiles? Initialization can rewrite config; preserve other options from backup.'
cm init
run bash "$validate" --preflight --source "$root" --config "$config"
cm execute-template '{{ includeTemplate ".chezmoitemplates/profile-records" . }}' > "$scratch/profiles"
printf 'Preview: review every managed target and back up any additional target that would be replaced.\n'
run "$root/scripts/beginner/preview.sh"
require 'LOCAL DEPLOYMENT: have you reviewed the preview and backed up affected existing targets, and approve apply?'
cm apply
printf '\nGit include, added once in the appropriate user-owned global config:\n[include]\n    path = ~/.config/git/mac-dotfiles.inc\n'
printf 'If global config does not exist, saving it in Vim creates it. Preserve unrelated settings; remove only reviewed conflicting default authors.\n'
require 'LOCAL CHANGE: open the global Git entrypoint in Vim?'
git_entry="$HOME/.gitconfig"
if [[ ! -e $git_entry && -f "$HOME/.config/git/config" ]]; then git_entry="$HOME/.config/git/config"; fi
run vim "$git_entry" < /dev/tty
printf '\nSSH include: put Include ~/.ssh/config.d/mac-dotfiles.conf near the top, outside Host/Match blocks. Preserve unrelated settings.\n'
require 'LOCAL CHANGE: open the SSH entrypoint in Vim?'
run vim "$HOME/.ssh/config" < /dev/tty
require 'LOCAL PERMISSIONS CHANGE: set only the SSH entrypoint to mode 600?'
[[ -f "$HOME/.ssh/config" && ! -L "$HOME/.ssh/config" ]] || fail 'Review the SSH entrypoint path before changing permissions.'
chmod 600 "$HOME/.ssh/config"
require 'LOCAL CHANGE: create the repository root directories declared in the validated profiles?'
while IFS=$'\t' read -r kind id path rest; do
    [[ $kind == R ]] || continue
    run mkdir -p "$path" < /dev/null
done < "$scratch/profiles"
while IFS=$'\t' read -r kind id name email alias host port user key account; do
    [[ $kind == P ]] || continue
    printf '\nProfile %s: account %s at %s via %s; key path %s\n' "$id" "$account" "$host" "$alias" "$key"
    if [[ -e $key || -L $key || -e $key.pub || -L $key.pub ]]; then
        printf 'Existing private/public path detected; generation is disabled. Edit the local profile and rerun to select a different path.\n'
        [[ -f $key && ! -L $key && -f $key.pub && ! -L $key.pub ]] || fail 'A reusable regular key pair is required; review occupied paths manually.'
        require "Reuse the existing key pair for profile $id?"
        if ask "LOCAL PERMISSIONS CHANGE: set only this reused private key to mode 600 for $id?"; then
            run "$root/scripts/beginner/key-permissions.sh" "$key" < /dev/null
        fi
    else
        require "CREDENTIAL CREATION: generate an Ed25519 key for $id? Enter a strong NONEMPTY passphrase in ssh-keygen."
        [[ ! -e $key && ! -L $key && ! -e $key.pub && ! -L $key.pub ]] || fail 'Key path became occupied.'
        [[ -d $(dirname "$key") ]] || fail 'Key parent directory is missing; create it deliberately and rerun.'
        run "$keygen" -t ed25519 -f "$key" -C "$id SSH authentication" < /dev/tty
        [[ -f $key && ! -L $key && -f $key.pub && ! -L $key.pub ]] || fail 'Key creation did not leave a regular key pair.'
        # Native tool decrypts locally; discard public output. Never collect a passphrase.
        if run "$keygen" -y -P '' -f "$key" < /dev/null > /dev/null 2>&1; then
            fail 'New key has an empty passphrase. Keep it; set a passphrase manually with ssh-keygen -p, then rerun.'
        fi
        run "$keygen" -l -f "$key" < /dev/null > /dev/null || fail 'New private key is invalid; review manually.'
        run "$keygen" -l -f "$key.pub" < /dev/null > /dev/null || fail 'New public key is invalid; review manually.'
    fi
    if ask "CREDENTIAL CHANGE: enroll this key for $id in Apple ssh-agent and macOS Keychain?"; then
        run "$root/scripts/beginner/enroll-keys.sh" "$key" < /dev/tty
    else
        printf 'SKIPPED: explicit enrollment; interactive SSH may prompt and cache the key per managed configuration. Batch checks cannot prompt.\n'
    fi
    printf 'BROWSER REGISTRATION for %s on %s: Settings -> SSH and GPG keys -> New SSH key. Choose Authentication Key, enter a machine title, paste the PUBLIC key into Key, then Add SSH key. Confirm the browser account.\n' "$account" "$host"
    if ask "CLIPBOARD CHANGE: copy only the .pub public key for $id?"; then
        [[ -f $key.pub && ! -L $key.pub ]] || fail 'Review the public-key path.'
        run pbcopy < "$key.pub"
    fi
    require "Confirm the public key is registered with the intended account for $id (or was already registered)?"
done < "$scratch/profiles"
run bash "$validate" --source "$root" --config "$config"
if ask 'NETWORK ACTION: connect interactively to each alias? Compare SERVER fingerprints with the trusted host documentation, not your account key.'; then
    printf 'GitHub.com server fingerprints: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints\nFor Enterprise, use the administrator-provided fingerprint. Never bypass host verification.\n'
    while IFS=$'\t' read -r kind id name email alias host port user key account; do
        [[ $kind == P ]] || continue
        require "NETWORK ACTION: connect profile $id to $host, and review host fingerprint and account greeting?"
        rc=0
        run "$ssh_bin" -T -o StrictHostKeyChecking=ask "${user}@${alias}" < /dev/tty || rc=$?
        ((rc == 0 || rc == 1)) || fail "Connection failed for $id (status $rc)."
        require "Did you verify the server fingerprint and a successful greeting for expected account $account?"
    done < "$scratch/profiles"
else
    printf 'SKIPPED: interactive connections; connectivity unverified.\n'
fi
if ask 'NETWORK ACTION: run bounded batch authentication checks for every profile? Keys must already be unlocked and host records trusted.'; then
    run bash "$root/scripts/check-connectivity.sh" --source "$root" --config "$config" < /dev/null
    printf 'PASS: setup and all profile connectivity checks completed.\n'
else
    printf 'PASS: local setup validated. SKIPPED: batch checks; connectivity unverified.\n'
fi
