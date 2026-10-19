#!/bin/bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
reference_file="$root/homeops-version"
state_dir="${HOME}/Library/Application Support/HomeOps"
marker="$state_dir/installation-reference"
upgrade=0

usage() {
    printf 'Usage: %s [--upgrade]\n' "${0##*/}"
}

if [[ ${1:-} == "--upgrade" ]]; then
    upgrade=1
elif [[ ${1:-} ]]; then
    usage >&2
    exit 2
fi

[[ -r "$reference_file" ]] || { printf 'HomeOps reference file is missing: %s\n' "$reference_file" >&2; exit 1; }
reference=$(tr -d '[:space:]' < "$reference_file")
[[ "$reference" =~ ^[0-9a-f]{40}$ ]] || {
    printf 'HomeOps reference must be a 40-character commit SHA\n' >&2
    exit 1
}
command -v uv >/dev/null 2>&1 || { printf 'uv is required; select Brewfile.homeops first\n' >&2; exit 1; }

installed=""
if [[ -f "$marker" ]]; then
    installed=$(tr -d '[:space:]' < "$marker")
fi
if [[ "$installed" == "$reference" ]]; then
    printf 'HomeOps is already installed at %s\n' "$reference"
    exit 0
fi
if [[ -n "$installed" && $upgrade -ne 1 ]]; then
    printf 'HomeOps reference mismatch (installed %s, declared %s); rerun with --upgrade to replace it\n' \
        "$installed" "$reference" >&2
    exit 1
fi

mkdir -p "$state_dir"
uv tool install --force "git+https://github.com/c-luu/homeops.git@${reference}"
printf '%s\n' "$reference" > "$marker"
printf 'Installed HomeOps at %s\n' "$reference"
