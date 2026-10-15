#!/bin/bash
source "$(dirname "$0")/lib.sh"
mkdir -p "$FIXTURE/public"
git -C "$FIXTURE/public" init -q
cp "$REPO/.gitignore" "$FIXTURE/public/.gitignore"
printf 'Generic github.example.com and git@github-account-a\n' > "$FIXTURE/public/safe.txt"
git -C "$FIXTURE/public" add .gitignore safe.txt
publication() { bash "$REPO/scripts/validate.sh" --publication-only --checkout "$FIXTURE/public"; }
publication
printf '%s%s\n' '-----BEGIN ' 'OPENSSH PRIVATE KEY-----' > "$FIXTURE/public/staged.txt"
git -C "$FIXTURE/public" add staged.txt
printf 'cleaned working file\n' > "$FIXTURE/public/staged.txt"
expect_failure publication
/usr/bin/grep -q 'index entry' "$FIXTURE/negative.out" || fail 'staged secret missed'
if /usr/bin/grep -q 'PRIVATE KEY-----' "$FIXTURE/negative.out"; then fail 'secret echoed'; fi
# No commits: remove the index entry through plumbing only in this fixture repository.
git -C "$FIXTURE/public" update-index --force-remove staged.txt
mkdir -p "$FIXTURE/public/.config/gh"
printf 'generic forbidden content\n' > "$FIXTURE/public/.config/gh/hosts.yml"
git -C "$FIXTURE/public" add -f .config/gh/hosts.yml
expect_failure publication
git -C "$FIXTURE/public" update-index --force-remove .config/gh/hosts.yml
weird=$'unusual\nname.txt'
printf 'safe\0binary\n' > "$FIXTURE/public/$weird"
git -C "$FIXTURE/public" add "$weird"
publication
rm "$FIXTURE/public/$weird"
publication
# A binary payload does not hide a marker.
printf '\0%s%s\n' '-----BEGIN ' 'RSA PRIVATE KEY-----' > "$FIXTURE/public/binary"
git -C "$FIXTURE/public" add binary
expect_failure publication
git -C "$FIXTURE/public" update-index --force-remove binary
ln -s /nonexistent "$FIXTURE/public/link"
git -C "$FIXTURE/public" add link
expect_failure publication
/usr/bin/grep -q NOT_PERFORMED "$FIXTURE/negative.out" || fail 'unsupported scan passed'
printf 'PASS: index/working-tree separation, force-added ignores, NUL names, binary content, deletion, scan incompleteness\n'
