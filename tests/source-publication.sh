#!/bin/bash
source "$(dirname "$0")/lib.sh"
mkdir -p "$FIXTURE/public-source"
git -C "$REPO" ls-files --cached --others --exclude-standard -z > "$FIXTURE/source-files"
while IFS= read -r -d '' file; do
    [[ -f "$REPO/$file" || -L "$REPO/$file" ]] || continue
    mkdir -p "$FIXTURE/public-source/$(dirname "$file")"
    cp -P "$REPO/$file" "$FIXTURE/public-source/$file"
done < "$FIXTURE/source-files"
git -C "$FIXTURE/public-source" init --template= -q
git -C "$FIXTURE/public-source" add .
bash "$REPO/scripts/validate.sh" --publication-only --checkout "$FIXTURE/public-source"
printf 'PASS: tracked and untracked publishable source scanned using a disposable index\n'
