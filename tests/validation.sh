#!/bin/bash
source "$(dirname "$0")/lib.sh"
profile account-a github-account-a github.com
cm apply
validate() { GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$FIXTURE/target/.gitconfig" CHEZMOI="$CHEZMOI" bash "$REPO/scripts/validate.sh" --source "$FIXTURE/source" --config "$FIXTURE/config.toml" --destination "$FIXTURE/target" "$@"; }
validate --preflight
expect_failure validate
/usr/bin/grep -q CREDENTIAL_MISSING "$FIXTURE/negative.out" || fail 'missing credential not classified'
mkdir -p "$FIXTURE/keys"
: > "$FIXTURE/keys/account-a" # Empty metadata fixture, not generated private key material.
chmod 600 "$FIXTURE/keys/account-a"
printf 'Include "%s"\n' "$FIXTURE/target/.ssh/config.d/mac-dotfiles.conf" > "$FIXTURE/target/.ssh/config"
printf '[include]\n path = "%s"\n' "$FIXTURE/target/.config/git/mac-dotfiles.inc" > "$FIXTURE/target/.gitconfig"
chmod 600 "$FIXTURE/target/.ssh/config"
validate
chmod 644 "$FIXTURE/target/.ssh/config.d/mac-dotfiles.conf"
expect_failure validate
chmod 600 "$FIXTURE/target/.ssh/config.d/mac-dotfiles.conf"
expect_failure env CHEZMOI=/missing/chezmoi bash "$REPO/scripts/validate.sh" --preflight
/usr/bin/grep -q NOT_PERFORMED "$FIXTURE/negative.out" || fail 'missing tool passed'
printf 'PASS: dependency, credential, and permissions diagnostics without repair\n'
validate
cp "$FIXTURE/target/.ssh/config" "$FIXTURE/safe-config"
printf 'Host *\n IdentityFile /tmp/extra\n' >> "$FIXTURE/target/.ssh/config"
expect_failure validate
/usr/bin/grep -q ambiguous "$FIXTURE/negative.out" || fail 'extra identity accepted'
cp "$FIXTURE/safe-config" "$FIXTURE/target/.ssh/config"
printf 'Match exec "touch %s"\n' "$FIXTURE/sentinel" >> "$FIXTURE/target/.ssh/config"
expect_failure validate
[[ ! -e "$FIXTURE/sentinel" ]] || fail 'unsafe command executed'
/usr/bin/grep -q NOT_PERFORMED "$FIXTURE/negative.out" || fail 'unsafe evaluation accepted'
cp "$FIXTURE/safe-config" "$FIXTURE/nested"
printf 'Include "%s"\n' "$FIXTURE/nested" > "$FIXTURE/target/.ssh/config"
validate
printf 'Include /nonexistent/required-config\n' > "$FIXTURE/target/.ssh/config"
expect_failure validate
printf 'Host github-account-a\n User wrong\nInclude "%s"\n' "$FIXTURE/target/.ssh/config.d/mac-dotfiles.conf" > "$FIXTURE/target/.ssh/config"
expect_failure validate
cp "$FIXTURE/safe-config" "$FIXTURE/target/.ssh/config"
printf 'PASS: SSH safety, nested includes, missing includes, overrides, additive keys\n'

validate
printf '[user]\n name = Wrong Fallback\n email = wrong@example.com\n' >> "$FIXTURE/target/.gitconfig"
expect_failure validate
/usr/bin/grep -q 'global fallback' "$FIXTURE/negative.out" || fail 'fallback accepted'
sed '/\[user\]/,$d' "$FIXTURE/target/.gitconfig" > "$FIXTURE/global-clean"
mv "$FIXTURE/global-clean" "$FIXTURE/target/.gitconfig"
validate
mkdir -p "$FIXTURE/repos/account-a/project"
GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$FIXTURE/target/.gitconfig" git -C "$FIXTURE/repos/account-a/project" init -q
validate --repository "$FIXTURE/repos/account-a/project"
git -C "$FIXTURE/repos/account-a/project" config user.email 'override@example.com'
expect_failure validate --repository "$FIXTURE/repos/account-a/project"
expect_failure env GIT_AUTHOR_EMAIL=override@example.com GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$FIXTURE/target/.gitconfig" CHEZMOI="$CHEZMOI" bash "$REPO/scripts/validate.sh" --source "$FIXTURE/source" --config "$FIXTURE/config.toml" --destination "$FIXTURE/target"
printf 'PASS: effective Git routing, inherited fallback, local/environment override reporting\n'
# Validation never creates a repository in a configured real profile root.
rm -rf "$FIXTURE/repos"
validate
[[ ! -e "$FIXTURE/repos" ]] || fail 'validator touched profile directories'
printf '# drift\n' >> "$FIXTURE/target/.config/git/account-a.inc"
expect_failure validate
/usr/bin/grep -q 'differs from source' "$FIXTURE/negative.out" || fail 'author drift not detected'
cm apply --force
cp "$FIXTURE/target/.gitconfig" "$FIXTURE/git-include"
: > "$FIXTURE/target/.gitconfig"
expect_failure validate
/usr/bin/grep -q 'include integration' "$FIXTURE/negative.out" || fail 'missing Git include not detected'
cp "$FIXTURE/git-include" "$FIXTURE/target/.gitconfig"
validate
printf 'PASS: deployed drift, missing integration, profile directories untouched\n'

chmod 400 "$FIXTURE/keys/account-a"
validate
printf 'Host github-account-a\n UseKeychain no\nInclude "%s"\n' "$FIXTURE/target/.ssh/config.d/mac-dotfiles.conf" > "$FIXTURE/target/.ssh/config"
expect_failure validate
/usr/bin/grep -q 'Keychain use' "$FIXTURE/negative.out" || fail 'Keychain override not detected'
printf 'PASS: read-only key permissions and applicable Keychain override\n'
