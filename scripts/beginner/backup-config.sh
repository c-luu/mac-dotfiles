#!/bin/bash
# Back up entrypoints and the local profile registry, never private keys.
set -euo pipefail
umask 077
backup_dir=${1:-"$HOME/mac-dotfiles-backups"}
mkdir -p "$backup_dir"
chmod 700 "$backup_dir"
backup() {
    local answer=''
    if [[ -f $1 ]]; then
        if [[ -e "$backup_dir/$2" || -L "$backup_dir/$2" ]]; then
            printf 'Overwrite %s? [y/N] ' "$backup_dir/$2" >&2
            read -r answer || answer=''
            case $answer in
                y|Y|yes|YES) ;;
                *) return 0 ;;
            esac
        fi
        cp -p "$1" "$backup_dir/$2"
    fi
}
backup "$HOME/.config/chezmoi/chezmoi.toml" chezmoi.toml
backup "$HOME/.gitconfig" gitconfig
backup "$HOME/.config/git/config" git-config
backup "$HOME/.ssh/config" ssh-config
printf 'Backups: %s\n' "$backup_dir"
