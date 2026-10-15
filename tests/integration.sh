#!/bin/bash
source "$(dirname "$0")/lib.sh"
profile account-a github-account-a github.com
profile account-b github-account-b github.com
profile enterprise git-enterprise github.example.com 2222
mkdir -p "$FIXTURE/target/.ssh" "$FIXTURE/keys"
printf 'unrelated content\n' > "$FIXTURE/target/.ssh/unrelated"
printf '[core]\n editor = example-editor\n' > "$FIXTURE/target/.gitconfig"
cm init
cm diff > "$FIXTURE/preview"
cm apply --dry-run --verbose > "$FIXTURE/dry-run"
[[ ! -f "$FIXTURE/target/.ssh/config.d/mac-dotfiles.conf" ]] || fail 'preview wrote targets'
cm apply
for id in account-a account-b enterprise; do : > "$FIXTURE/keys/$id"; chmod 600 "$FIXTURE/keys/$id"; done
printf '[include]\n path = "%s"\n' "$FIXTURE/target/.config/git/mac-dotfiles.inc" >> "$FIXTURE/target/.gitconfig"
printf 'Include "%s"\nHost unrelated\n HostName example.org\n User other\n' "$FIXTURE/target/.ssh/config.d/mac-dotfiles.conf" > "$FIXTURE/target/.ssh/config"
chmod 600 "$FIXTURE/target/.ssh/config"
validate() { GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$FIXTURE/target/.gitconfig" CHEZMOI="$CHEZMOI" bash "$REPO/scripts/validate.sh" --source "$FIXTURE/source" --config "$FIXTURE/config.toml" --destination "$FIXTURE/target" "$@"; }
validate
[[ ! -e "$FIXTURE/repos" ]] || fail 'profile directories created'
cm verify
cm apply
[[ -z $(cm diff) ]] || fail 'second apply changed targets'
[[ $(cat "$FIXTURE/target/.ssh/unrelated") == 'unrelated content' ]] || fail 'unrelated file changed'
[[ $(git config --file "$FIXTURE/target/.gitconfig" core.editor) == example-editor ]] || fail 'unrelated setting changed'
printf '# local drift\n' >> "$FIXTURE/target/.config/git/account-a.inc"
expect_failure cm verify
expect_failure validate
cm diff > "$FIXTURE/drift"
/usr/bin/grep -q 'local drift' "$FIXTURE/drift" || fail 'drift not shown'
cm apply --force # Restore only the deliberately altered fixture after reviewing diff.
cm verify
validate
printf 'PASS: full initialization/preview/apply/integration/validation/drift/reapply with unrelated state preserved\n'
