#!/bin/bash
set -euo pipefail
source_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
chezmoi --source "$source_dir" diff
chezmoi --source "$source_dir" verify
