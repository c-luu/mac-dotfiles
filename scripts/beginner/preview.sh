#!/bin/bash
# Resolve the checkout from this script, regardless of the working directory.
set -euo pipefail
source_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
chezmoi --source "$source_dir" managed
chezmoi --source "$source_dir" diff
chezmoi --source "$source_dir" apply --dry-run --verbose
