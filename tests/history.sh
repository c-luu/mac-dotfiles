#!/bin/bash
source "$(dirname "$0")/lib.sh"
mkdir "$FIXTURE/history"
cd "$FIXTURE/history"
git init --template= -q
git config user.name 'Fixture Author'
git config user.email 'fixture@example.com'
printf 'baseline\n' > README.md
git add README.md
git commit -qm baseline
base=$(git rev-parse HEAD)
git branch private-history
mkdir scripts
printf 'implementation\n' > scripts/example.sh
git add scripts
git commit -qm implementation
bash "$REPO/scripts/check-public-history.sh" "$base" HEAD private-history
mkdir openspec
printf 'planning\n' > openspec/plan.md
git add openspec
git commit -qm planning
git rm -q openspec/plan.md
git commit -qm remove-plan
expect_failure bash "$REPO/scripts/check-public-history.sh" "$base" HEAD
# Even implementation-only commits from an excluded branch must not be imported.
git branch excluded HEAD~2
expect_failure bash "$REPO/scripts/check-public-history.sh" "$base" HEAD~2 excluded
printf 'PASS: history checks reject add-then-delete plans and excluded ancestors\n'
