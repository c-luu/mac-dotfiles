#!/bin/bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
reference_file="$root/homeops-version"
state_dir="${HOMEOPS_INSTALL_STATE_DIR:-${HOME}/Library/Application Support/HomeOps}"
marker="$state_dir/installation-reference"
uv_executable=${HOMEOPS_UV:-uv}
upgrade=0

usage() {
    printf 'Usage: %s [--upgrade]\n' "${0##*/}"
}

if [[ $# -gt 1 ]]; then
    usage >&2
    exit 2
fi
if [[ ${1:-} == "--upgrade" ]]; then
    upgrade=1
elif [[ ${1:-} ]]; then
    usage >&2
    exit 2
fi

[[ "$state_dir" == /* ]] || { printf 'Installer state directory must be absolute\n' >&2; exit 1; }
[[ -r "$reference_file" ]] || { printf 'HomeOps reference file is missing\n' >&2; exit 1; }
reference=$(cat "$reference_file")
[[ "$reference" =~ ^[0-9a-f]{40}$ ]] || {
    printf 'HomeOps reference must be a single 40-character commit SHA\n' >&2
    exit 1
}
command -v "$uv_executable" >/dev/null 2>&1 || {
    printf 'uv is required; select Brewfile.homeops first\n' >&2
    exit 1
}
tool_dir=$("$uv_executable" tool dir)
[[ "$tool_dir" == /* ]] || { printf 'uv returned an invalid tool directory\n' >&2; exit 1; }
installed_python="$tool_dir/homeops/bin/python"

read_installed_revision() {
    [[ -x "$installed_python" ]] || return 1
    "$installed_python" -I "$root/scripts/homeops-installed-revision.py"
}

write_marker() {
    mkdir -p "$state_dir"
    local temporary
    temporary=$(mktemp "$state_dir/.homeops-reference.XXXXXX")
    if ! printf '%s\n' "$reference" > "$temporary" || ! mv -f "$temporary" "$marker"; then
        rm -f "$temporary"
        return 1
    fi
}

installed=unknown
if ! installed=$(read_installed_revision); then installed=unknown; fi
if [[ "$installed" == "$reference" ]]; then
    write_marker
    printf 'HomeOps is already installed at verified commit %s; no replacement\n' "$reference"
    exit 0
fi
existing=0
if [[ -e "$tool_dir/homeops" ]] || command -v homeops >/dev/null 2>&1; then existing=1; fi
if [[ $existing -eq 1 && $upgrade -ne 1 ]]; then
    printf 'HomeOps installation mismatch or unverifiable source (installed %s, declared %s); rerun with --upgrade to replace it\n' \
        "$installed" "$reference" >&2
    exit 1
fi

arguments=(tool install --with trafilatura)
if [[ $existing -eq 1 ]]; then arguments+=(--force); fi
arguments+=("git+https://github.com/c-luu/homeops.git@${reference}")
"$uv_executable" "${arguments[@]}"
if ! installed=$(read_installed_revision) || [[ "$installed" != "$reference" ]]; then
    printf 'HomeOps installed revision could not be verified; installation marker left unchanged\n' >&2
    exit 1
fi
write_marker
printf 'Installed and verified HomeOps at commit %s\n' "$reference"
