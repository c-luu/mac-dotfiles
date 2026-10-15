#!/bin/bash
source "$(dirname "$0")/lib.sh"
export HOME="$FIXTURE/user home"
mkdir -p "$HOME/.config/chezmoi" "$HOME/.ssh" "$FIXTURE/bin"
printf 'profile fixture\n' > "$HOME/.config/chezmoi/chezmoi.toml"
printf 'git fixture\n' > "$HOME/.gitconfig"
printf 'private fixture\n' > "$HOME/.ssh/key"
"$REPO/scripts/beginner/backup-config.sh" >/dev/null
cmp "$HOME/.gitconfig" "$HOME/mac-dotfiles-backups/gitconfig"
cmp "$HOME/.config/chezmoi/chezmoi.toml" "$HOME/mac-dotfiles-backups/chezmoi.toml"
[[ ! -e "$HOME/mac-dotfiles-backups/key" ]] || fail 'backup copied a key'
[[ $(stat -f '%OLp' "$HOME/mac-dotfiles-backups") == 700 ]] || fail 'backup directory mode'
printf 'changed fixture\n' > "$HOME/.gitconfig"
"$REPO/scripts/beginner/backup-config.sh" </dev/null >/dev/null 2>&1
[[ $(cat "$HOME/mac-dotfiles-backups/gitconfig") == 'git fixture' ]] || fail 'backup overwritten without consent'
chmod 644 "$HOME/.ssh/key"
expect_failure "$REPO/scripts/beginner/key-permissions.sh" "$HOME/.ssh/key" "$HOME/.ssh/missing"
[[ $(stat -f '%OLp' "$HOME/.ssh/key") == 644 ]] || fail 'partially changed permissions'
"$REPO/scripts/beginner/key-permissions.sh" "$HOME/.ssh/key"
[[ $(stat -f '%OLp' "$HOME/.ssh/key") == 600 ]] || fail 'private-key mode'
expect_failure "$REPO/scripts/beginner/enroll-keys.sh"
expect_failure "$REPO/scripts/beginner/enroll-keys.sh" "$HOME/.ssh/missing"
expect_failure "$REPO/scripts/beginner/connect.sh"
expect_failure "$REPO/scripts/beginner/connect.sh" '-oProxyCommand=bad'
cat > "$FIXTURE/bin/chezmoi" <<'MOCK'
#!/bin/bash
printf '%s\n' "$*" >> "$COMMAND_LOG"
[[ $2 == "$EXPECTED_SOURCE" ]] || exit 3
[[ ${FAIL_DIFF:-0} != 1 || $3 != diff ]]
MOCK
cat > "$FIXTURE/bin/vim" <<'MOCK'
#!/bin/bash
[[ -d "$HOME/.config/chezmoi" && $1 == "$HOME/.config/chezmoi/chezmoi.toml" ]]
MOCK
chmod +x "$FIXTURE/bin/chezmoi" "$FIXTURE/bin/vim"
export PATH="$FIXTURE/bin:$PATH" COMMAND_LOG="$FIXTURE/commands" EXPECTED_SOURCE="$REPO"
cd "$FIXTURE"
"$REPO/scripts/beginner/edit-profiles.sh"
"$REPO/scripts/beginner/preview.sh"
[[ $(wc -l < "$COMMAND_LOG" | tr -d ' ') == 3 ]] || fail 'preview commands'
rg -q -- 'apply --dry-run --verbose$' "$COMMAND_LOG" || fail 'preview must be dry-run'
: > "$COMMAND_LOG"
"$REPO/scripts/beginner/check-drift.sh"
[[ $(wc -l < "$COMMAND_LOG" | tr -d ' ') == 2 ]] || fail 'drift commands'
export FAIL_DIFF=1
: > "$COMMAND_LOG"
expect_failure "$REPO/scripts/beginner/preview.sh"
[[ $(wc -l < "$COMMAND_LOG" | tr -d ' ') == 2 ]] || fail 'preview continued after failure'
printf 'PASS: beginner workflows in isolated home; no credentials or network used\n'
