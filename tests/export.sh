#!/bin/bash
source "$(dirname "$0")/lib.sh"
mkdir -p "$FIXTURE/export-source/scripts" "$FIXTURE/export-source/openspec" "$FIXTURE/export-source/.agents/skills/openspec-fixture"
cp "$REPO/scripts/prepare-public-source.sh" "$FIXTURE/export-source/scripts/"
printf 'generic fixture\n' > "$FIXTURE/export-source/README.md"
printf 'planning fixture\n' > "$FIXTURE/export-source/openspec/plan.md"
printf 'planning prompt\n' > "$FIXTURE/export-source/.agents/skills/openspec-fixture/SKILL.md"
git -C "$FIXTURE/export-source" init --template= -q
git -C "$FIXTURE/export-source" config user.name 'Fixture Author'
git -C "$FIXTURE/export-source" config user.email 'fixture@example.com'
git -C "$FIXTURE/export-source" add .
git -C "$FIXTURE/export-source" commit -qm fixture
source_commit=$(git -C "$FIXTURE/export-source" rev-parse HEAD)
exporter="$FIXTURE/export-source/scripts/prepare-public-source.sh"
bash "$exporter" HEAD "$FIXTURE/fresh public"
[[ -x "$FIXTURE/fresh public/scripts/prepare-public-source.sh" && ! -e "$FIXTURE/fresh public/openspec" && ! -e "$FIXTURE/fresh public/.agents" && ! -e "$FIXTURE/fresh public/.git" ]] || fail 'export boundary or executable mode'
expect_failure bash "$exporter" HEAD "$FIXTURE/fresh public"
ln -s "$FIXTURE/nonexistent" "$FIXTURE/link"
expect_failure bash "$exporter" HEAD "$FIXTURE/link"
expect_failure bash "$exporter" HEAD "$FIXTURE/export-source/inside"
expect_failure bash "$exporter" no-such-revision "$FIXTURE/invalid"
printf 'dirty\n' >> "$FIXTURE/export-source/README.md"
expect_failure bash "$exporter" HEAD "$FIXTURE/dirty-export"
git -C "$FIXTURE/export-source" restore README.md
ln -s /not/a/source/file "$FIXTURE/export-source/scripts/unsafe"
git -C "$FIXTURE/export-source" add scripts/unsafe
git -C "$FIXTURE/export-source" commit -qm unsafe
expect_failure bash "$exporter" HEAD "$FIXTURE/unsafe-export"
[[ ! -e "$FIXTURE/unsafe-export" ]] || fail 'unsafe export partially written'
git -C "$FIXTURE/fresh public" init --template= -q
git -C "$FIXTURE/fresh public" config user.name 'Public Fixture'
git -C "$FIXTURE/fresh public" config user.email 'public@example.com'
git -C "$FIXTURE/fresh public" add .
git -C "$FIXTURE/fresh public" commit -qm 'Initial public source'
[[ $(git -C "$FIXTURE/fresh public" rev-list --all --count) == 1 ]] || fail 'fresh history not isolated'
if git -C "$FIXTURE/fresh public" cat-file -e "$source_commit" 2>/dev/null; then fail 'source history copied'; fi
[[ $(git -C "$FIXTURE/fresh public" log -1 --format='%an <%ae> | %cn <%ce>') == 'Public Fixture <public@example.com> | Public Fixture <public@example.com>' ]] || fail 'public metadata'
printf 'PASS: clean selected export, safe destination, modes, planning exclusion, fresh history and metadata\n'
