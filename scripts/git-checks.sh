#!/bin/bash
# All writes belong to disposable fixtures. Actual repositories are queried only on request.
fixture_git() {
    env -u GIT_DIR -u GIT_WORK_TREE -u GIT_COMMON_DIR -u GIT_CONFIG_PARAMETERS -u GIT_CONFIG_COUNT \
        -u GIT_AUTHOR_NAME -u GIT_AUTHOR_EMAIL -u GIT_COMMITTER_NAME -u GIT_COMMITTER_EMAIL -u EMAIL \
        GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$SCRATCH/fixture-global" git "$@"
}
global_git() {
    env -u GIT_DIR -u GIT_WORK_TREE -u GIT_COMMON_DIR GIT_CEILING_DIRECTORIES="$SCRATCH" git -C "$SCRATCH" config --includes "$@"
}
check_git() {
    local kind id root field name email actual expected origin var n=0 location target rc
    for var in GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL EMAIL GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR; do
        [[ -z ${!var-} ]] || problem FAIL "Git identity/config environment override present: $var"
    done
    # No repository discovery here: evaluate unconditional system/global configuration.
    for field in user.name user.email author.name author.email committer.name committer.email; do
        if global_git --get "$field" > "$SCRATCH/git-value" 2>/dev/null; then
            problem FAIL "global fallback author detected: $field; review its origin locally"
        else
            rc=$?; [[ $rc == 1 ]] || problem NOT_PERFORMED 'Git global configuration query failed'
        fi
    done
    origin=$(global_git --show-origin --get user.useConfigOnly 2>/dev/null) || origin=''
    [[ $origin == "file:$DESTINATION/.config/git/mac-dotfiles.inc"$'\ttrue' ]] || problem FAIL 'managed Git include integration or explicit-only policy is missing/overridden'
    # Verify actual deployed bytes, without deploying or repairing anything.
    for target in "$DESTINATION/.config/git/mac-dotfiles.inc"; do
        if ! cm cat "$target" > "$SCRATCH/rendered" 2> "$SCRATCH/render-errors" || ! cmp -s "$target" "$SCRATCH/rendered"; then problem FAIL 'deployed Git routing differs from rendered source'; fi
    done
    : > "$SCRATCH/fixture-global"
    fixture_git config --file "$SCRATCH/fixture-global" user.useConfigOnly true
    while IFS=$'\t' read -r kind id name email rest; do
        [[ $kind == P ]] || continue
        target="$DESTINATION/.config/git/$id.inc"
        if ! cm cat "$target" > "$SCRATCH/rendered" 2> "$SCRATCH/render-errors" || ! cmp -s "$target" "$SCRATCH/rendered"; then problem FAIL "deployed author fragment differs from source for profile $id"; fi
    done < "$SCRATCH/profiles"
    while IFS=$'\t' read -r kind id root; do
        [[ $kind == R ]] || continue
        n=$((n+1)); location="$SCRATCH/roots/$n"
        name=$(awk -F '\t' -v id="$id" '$1=="P" && $2==id {print $3}' "$SCRATCH/profiles")
        email=$(awk -F '\t' -v id="$id" '$1=="P" && $2==id {print $4}' "$SCRATCH/profiles")
        fixture_git config --file "$SCRATCH/fixture-global" --add "includeIf.gitdir:$location/.path" "$DESTINATION/.config/git/$id.inc"
        for location in "$location/project" "$location/nested/project"; do
            mkdir -p "$location"
            fixture_git -C "$location" init --template= -q > /dev/null 2>&1 || { problem NOT_PERFORMED 'temporary Git fixture initialization failed'; continue; }
            for field in user.name user.email; do
                if [[ $field == user.name ]]; then expected=$name; else expected=$email; fi
                actual=$(fixture_git -C "$location" config --get "$field" 2>/dev/null) || actual=''
                [[ $actual == "$expected" ]] || problem FAIL "temporary Git directory identity mismatch for profile $id ($field)"
            done
        done
    done < "$SCRATCH/profiles"
    mkdir -p "$SCRATCH/outside"
    if ! fixture_git -C "$SCRATCH/outside" init --template= -q > /dev/null 2>&1; then problem NOT_PERFORMED 'temporary unmanaged fixture initialization failed'
    elif fixture_git -C "$SCRATCH/outside" var GIT_AUTHOR_IDENT > /dev/null 2>&1; then problem FAIL 'temporary unmanaged repository inherited an author'; fi
    if [[ -n $SELECTED_REPOSITORY ]]; then check_selected_repository; fi
    report INFO 'Git routing checked in temporary repositories; actual project overrides require --repository'
}
check_selected_repository() {
    local resolved kind id root field expected actual origin matched=0 rc
    if ! resolved=$(git -C "$SELECTED_REPOSITORY" rev-parse --absolute-git-dir 2>/dev/null); then problem NOT_PERFORMED 'selected repository cannot be inspected'; return; fi
    while IFS=$'\t' read -r kind id root; do
        [[ $kind == R && $resolved == "$root/"* ]] || continue
        matched=1
        for field in user.name user.email; do
            if [[ $field == user.name ]]; then expected=$(awk -F '\t' -v id="$id" '$1=="P" && $2==id {print $3}' "$SCRATCH/profiles"); else expected=$(awk -F '\t' -v id="$id" '$1=="P" && $2==id {print $4}' "$SCRATCH/profiles"); fi
            actual=$(git -C "$SELECTED_REPOSITORY" config --includes --get "$field" 2>/dev/null) || actual=''
            origin=$(git -C "$SELECTED_REPOSITORY" config --includes --show-origin --get "$field" 2>/dev/null) || origin=''
            printf 'INFO: selected repository %s = %s (%s)\n' "$field" "$actual" "${origin%%$'\t'*}"
            [[ $actual == "$expected" ]] || problem FAIL 'selected repository author override conflicts with directory profile'
        done
    done < "$SCRATCH/profiles"
    if ((matched)); then
        for field in author.name author.email committer.name committer.email; do
            if git -C "$SELECTED_REPOSITORY" config --includes --get "$field" >/dev/null 2>&1; then problem FAIL "selected repository overrides $field; review locally"; else rc=$?; [[ $rc == 1 ]] || problem NOT_PERFORMED 'selected repository configuration query failed'; fi
        done
    else
        report INFO 'selected repository is outside profile roots; inspecting its explicit author'
        if ! git -C "$SELECTED_REPOSITORY" var GIT_AUTHOR_IDENT > "$SCRATCH/selected-author" 2>/dev/null; then problem FAIL 'selected unmanaged repository lacks an explicit author'; fi
    fi
}
