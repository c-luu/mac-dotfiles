#!/bin/bash
source "$(dirname "$0")/lib.sh"
bash "$REPO/scripts/check-guide.sh"
printf '```sh\nfirst\nsecond\n```\n' > "$FIXTURE/bad-guide.md"
expect_failure bash "$REPO/scripts/check-guide.sh" "$FIXTURE/bad-guide.md"
printf '```sh\n./scripts/does-not-exist.sh\n```\n' > "$FIXTURE/bad-guide.md"
expect_failure bash "$REPO/scripts/check-guide.sh" "$FIXTURE/bad-guide.md"
mkdir -p "$FIXTURE/privacy/scripts"
cp "$REPO/scripts/check-source-privacy.sh" "$FIXTURE/privacy/scripts/"
git -C "$FIXTURE/privacy" init --template= -q
printf 'Fictional-Private-Account\ninternal.example.invalid\nFixture-Machine-Private\n' > "$FIXTURE/terms"
printf 'generic account and git.example.com\n' > "$FIXTURE/privacy/README.md"
bash "$FIXTURE/privacy/scripts/check-source-privacy.sh" "$FIXTURE/terms"
printf 'Fictional-Private-Account\n' > "$FIXTURE/privacy/README.md"
expect_failure bash "$FIXTURE/privacy/scripts/check-source-privacy.sh" "$FIXTURE/terms"
if /usr/bin/grep -q 'Fictional-Private-Account' "$FIXTURE/negative.out"; then fail 'matched personal value leaked'; fi
printf 'generic account\n' > "$FIXTURE/privacy/README.md"
printf 'internal.example.invalid\n' > "$FIXTURE/privacy/new.md"
expect_failure bash "$FIXTURE/privacy/scripts/check-source-privacy.sh" "$FIXTURE/terms"
printf 'PASS: guide regression and tracked/new privacy review boundaries\n'
