#!/bin/bash
# Index plumbing preserves NUL-delimited names and scans index blobs independently.
forbidden_path() {
    local p=$1 base=${1##*/}
    case $p in
        .config/gh/*|*/.config/gh/*|.config/chezmoi/*|*/.config/chezmoi/*|secrets/*|*/secrets/*|.secrets/*|*/.secrets/*|backups/*|*/backups/*) return 0 ;;
    esac
    case $base in
        id_rsa*|id_dsa*|id_ecdsa*|id_ed25519*|*.pem|*.p12|*.pfx|*.key|.netrc|.git-credentials|credentials.json|auth.json|*_credentials.json|.env|.env.*|*.secret|*.secrets|chezmoi.toml|chezmoi.yaml|chezmoi.yml|chezmoi.json|hosts.yml|hosts.yaml|*.keychain*|*.local|*.local.toml|*.local.json|*.local.yaml|*.local.yml|profiles.local.*|*.bak|*.backup|*.log) return 0 ;;
    esac
    return 1
}
scan_blob() {
    local file=$1 label=$2 rc
    # Patterns are intentionally limited. Never print matched lines or token values.
    local pattern='-----BEGIN (OPENSSH|RSA|DSA|EC|ENCRYPTED|PGP) PRIVATE KEY( BLOCK)?-----|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{30,}|AKIA[A-Z0-9]{16}|[Bb]earer[[:space:]]+[A-Za-z0-9._-]{20,}'
    if LC_ALL=C /usr/bin/grep -aEq -- "$pattern" "$file"; then
        problem FAIL "obvious private material detected in $label"
    else
        rc=$?
        [[ $rc == 1 ]] || problem NOT_PERFORMED "content scan failed for $label"
    fi
}
check_publication() {
    local entry metadata file mode oid stage n=0 rc
    if ! git -C "$CHECKOUT" rev-parse --show-toplevel > "$SCRATCH/repo-root" 2>/dev/null; then problem NOT_PERFORMED 'publication checkout is not a Git repository'; return; fi
    CHECKOUT=$(cat "$SCRATCH/repo-root")
    if ! git -C "$CHECKOUT" ls-files --stage -z > "$SCRATCH/index-list" 2>/dev/null; then problem NOT_PERFORMED 'Git index enumeration failed'; return; fi
    while IFS= read -r -d '' entry; do
        n=$((n+1)); metadata=${entry%%$'\t'*}; file=${entry#*$'\t'}
        read -r mode oid stage <<< "$metadata"
        if [[ $stage != 0 || $mode == 160000 ]]; then problem NOT_PERFORMED "unmerged index or submodule entry #$n requires separate review"; continue; fi
        case $file in .env.example|.env.sample) ;; *) if forbidden_path "$file"; then problem FAIL "prohibited tracked/index path #$n"; fi ;; esac
        if ! git -C "$CHECKOUT" cat-file blob "$oid" > "$SCRATCH/blob" 2>/dev/null; then problem NOT_PERFORMED "index blob read failed for entry #$n"; continue; fi
        scan_blob "$SCRATCH/blob" "index entry #$n"
        if [[ -L "$CHECKOUT/$file" ]]; then
            problem NOT_PERFORMED "working-tree symlink entry #$n requires separate review"
        elif [[ -f "$CHECKOUT/$file" && -r "$CHECKOUT/$file" ]]; then
            scan_blob "$CHECKOUT/$file" "working-tree entry #$n"
        elif [[ -e "$CHECKOUT/$file" ]]; then
            problem NOT_PERFORMED "working-tree content unavailable for entry #$n"
        else
            # Deleted working files still have their index content scanned above.
            report INFO "working-tree entry #$n deleted; indexed content checked"
        fi
    done < "$SCRATCH/index-list"
    # Check exclusions independently: ignore rules cannot protect force-added files.
    for file in id_ed25519_example .config/gh/hosts.yml chezmoi.toml .env export.keychain-db backups/example; do
        if ! git -C "$CHECKOUT" check-ignore --no-index -q "$file"; then problem FAIL 'required ignore coverage missing'; fi
    done
    report INFO "publication scan covered $n index entries plus available tracked working copies; untracked files and history require separate review"
}
