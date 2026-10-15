#!/bin/bash
source "$(dirname "$0")/lib.sh"
profile account-a github-account-a github.com
profile account-b github-account-b github.com
profile enterprise git-enterprise github.example.com 2222
cm apply
cat > "$FIXTURE/mock-ssh" <<'MOCK'
#!/bin/bash
printf '%s\n' "$*" >> "$MOCK_LOG"
# SSH can consume stdin even with -T; model that to catch profile-loop truncation.
cat >/dev/null
case $MOCK_RESULT in
 success)
  case "${!#}" in github-account-a) account=account-a-example ;; github-account-b) account=account-b-example ;; git-enterprise) account=enterprise-example ;; *) exit 99 ;; esac
  printf "Hi %s! You've successfully authenticated, but GitHub does not provide shell access.\n" "$account"; exit 1 ;;
 mismatch) printf "Hi wrong-example! You've successfully authenticated, but GitHub does not provide shell access.\n"; exit 1 ;;
 denied) printf 'Permission denied (publickey).\n'; exit 255 ;;
 host) printf 'Host key verification failed.\n'; exit 255 ;;
 timeout) printf 'Connection timed out\n'; exit 255 ;;
 unknown) printf 'Enterprise custom response\n'; exit 1 ;;
esac
MOCK
chmod +x "$FIXTURE/mock-ssh"
connect() { MOCK_RESULT=$1 MOCK_LOG="$FIXTURE/mock-log" MAC_DOTFILES_TEST_SSH="$FIXTURE/mock-ssh" CHEZMOI="$CHEZMOI" bash "$REPO/scripts/check-connectivity.sh" --source "$FIXTURE/source" --config "$FIXTURE/config.toml" --destination "$FIXTURE/target"; }
connect success
[[ $(wc -l < "$FIXTURE/mock-log" | tr -d ' ') == 3 ]] || fail 'profile route count'
/usr/bin/grep -q StrictHostKeyChecking=yes "$FIXTURE/mock-log" || fail 'host verification bypass'
for result in mismatch denied host timeout unknown; do expect_failure connect "$result"; done
# Exercise the normal-home path, where SSH_ARGS is empty, using Apple's Bash 3.2.
# Override only chezmoi's homeDir metadata; retain isolated source/config/destination.
cat > "$FIXTURE/mock-chezmoi" <<'MOCK'
#!/bin/bash
if [[ ${!#} == '{{ .chezmoi.homeDir }}' ]]; then
    printf '%s\n' "$MOCK_PROFILE_HOME"
else
    exec "$REAL_CHEZMOI" "$@"
fi
MOCK
chmod +x "$FIXTURE/mock-chezmoi"
: > "$FIXTURE/mock-log"
REAL_CHEZMOI=$(command -v "$CHEZMOI") MOCK_PROFILE_HOME="$FIXTURE/target" \
    MOCK_RESULT=success MOCK_LOG="$FIXTURE/mock-log" MAC_DOTFILES_TEST_SSH="$FIXTURE/mock-ssh" \
    CHEZMOI="$FIXTURE/mock-chezmoi" /bin/bash "$REPO/scripts/check-connectivity.sh" \
    --source "$FIXTURE/source" --config "$FIXTURE/config.toml" --destination "$FIXTURE/target"
[[ $(wc -l < "$FIXTURE/mock-log" | tr -d ' ') == 3 ]] || fail 'normal-home route count'
if /usr/bin/grep -q -- '-F ' "$FIXTURE/mock-log"; then fail 'normal-home SSH should use default config'; fi
printf 'PASS: mocked authentication, exit 1, mismatch, denial, host verification, timeout, enterprise ambiguity\n'
