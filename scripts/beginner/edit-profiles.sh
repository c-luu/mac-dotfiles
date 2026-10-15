#!/bin/bash
set -euo pipefail
umask 077
mkdir -p "$HOME/.config/chezmoi"
exec vim "$HOME/.config/chezmoi/chezmoi.toml"
