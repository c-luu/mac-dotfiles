#!/bin/bash
source "$(dirname "$0")/lib.sh"
profile account-a github-account-a github.com
profile account-b github-account-b github.com
profile enterprise git-enterprise github.example.com 2222
cm managed > "$FIXTURE/managed"
if /usr/bin/grep -Eq 'README|openspec|Brewfile|scripts|\.github' "$FIXTURE/managed"; then fail 'unowned target'; fi
cm diff > "$FIXTURE/diff"
cm apply --dry-run --verbose > "$FIXTURE/dry"
[[ ! -e "$FIXTURE/target/.config/git/account-a.inc" ]] || fail 'preview mutated target'
cm apply
for id in account-a account-b enterprise; do
    [[ $(git config --file "$FIXTURE/target/.config/git/$id.inc" user.email) == "$id@example.com" ]] || fail 'incorrect author'
done
if git config --file "$FIXTURE/target/.config/git/mac-dotfiles.inc" user.email; then fail 'fallback author'; fi
printf 'PASS: Git templates and ownership preview\n'
printf '[include]\n path = "%s"\n[core]\n editor = example-editor\n' "$FIXTURE/target/.config/git/mac-dotfiles.inc" > "$FIXTURE/global"
clean_git() { env -i PATH="$PATH" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$FIXTURE/global" git "$@"; }
for id in account-a account-b enterprise; do
    mkdir -p "$FIXTURE/repos/$id/nested/project"
    clean_git -C "$FIXTURE/repos/$id/nested/project" init -q
    [[ $(clean_git -C "$FIXTURE/repos/$id/nested/project" config user.email) == "$id@example.com" ]] || fail "wrong routing: $id"
    clean_git -C "$FIXTURE/repos/$id/nested/project" var GIT_AUTHOR_IDENT > /dev/null
    [[ $(clean_git -C "$FIXTURE/repos/$id/nested/project" config core.editor) == example-editor ]] || fail 'unrelated Git setting lost'
done
mkdir -p "$FIXTURE/outside"
clean_git -C "$FIXTURE/outside" init -q
expect_failure clean_git -C "$FIXTURE/outside" var GIT_AUTHOR_IDENT
clean_git -C "$FIXTURE/outside" config user.name 'Explicit Local'
clean_git -C "$FIXTURE/outside" config user.email 'explicit@example.com'
clean_git -C "$FIXTURE/outside" var GIT_AUTHOR_IDENT > /dev/null
# Extend the source using the same reusable template, without changing routing code.
profile additional github-additional github.com
printf '{{ includeTemplate ".chezmoitemplates/git-author" (dict "id" "additional" "data" .) }}\n' > "$FIXTURE/source/home/dot_config/private_git/private_additional.inc.tmpl"
cm apply
mkdir -p "$FIXTURE/repos/additional/project"
clean_git -C "$FIXTURE/repos/additional/project" init -q
[[ $(clean_git -C "$FIXTURE/repos/additional/project" config user.email) == additional@example.com ]] || fail 'additional profile missing'
# One profile alone remains supported; unused generic entries are ignored.
sed '/\[data.profiles.account-b\]/,$d' "$FIXTURE/config.toml" > "$FIXTURE/single.toml"
cp "$FIXTURE/config.toml" "$FIXTURE/multiple.toml"
cp "$FIXTURE/single.toml" "$FIXTURE/config.toml"
rm "$FIXTURE/source/home/dot_config/private_git/private_additional.inc.tmpl"
cm managed > "$FIXTURE/single-managed"
if /usr/bin/grep -Eq 'account-b.inc|enterprise.inc' "$FIXTURE/single-managed"; then fail 'unused profile managed'; fi
printf 'PASS: independent/nested/extended/single Git profiles, no fallback, explicit local author\n'
