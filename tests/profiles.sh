#!/bin/bash
source "$(dirname "$0")/lib.sh"
profile account-a github-account-a github.com
profile account-b github-account-b github.com
profile enterprise git-enterprise github.example.com 2222
cm execute-template --init < "$FIXTURE/source/home/.chezmoi.toml.tmpl" > "$FIXTURE/rendered.toml"
cp "$FIXTURE/config.toml" "$FIXTURE/original.toml"
cm init
cm execute-template '{{ .profiles | toJson }}' > "$FIXTURE/profiles.json"
/usr/bin/grep -Eq 'Example.*Author' "$FIXTURE/profiles.json" || fail 'author input lost'
for bad in empty placeholder control alias overlap; do
    cp "$FIXTURE/original.toml" "$FIXTURE/config.toml"
    case $bad in
        empty) sed -i '' "s/account-a@example.com//" "$FIXTURE/config.toml" ;;
        placeholder) sed -i '' 's/account-a@example.com/REPLACE_ME/' "$FIXTURE/config.toml" ;;
        control) awk '/account-a@example.com/ { print "authorEmail = \"bad\\nemail\""; next } { print }' "$FIXTURE/config.toml" > "$FIXTURE/control.toml"; mv "$FIXTURE/control.toml" "$FIXTURE/config.toml" ;;
        alias) sed -i '' 's/github-account-b/github-account-a/' "$FIXTURE/config.toml" ;;
        overlap) sed -i '' 's|/repos/account-b|/repos/account-a/nested|' "$FIXTURE/config.toml" ;;
    esac
    expect_failure cm execute-template --init < "$FIXTURE/source/home/.chezmoi.toml.tmpl"
done
printf 'PASS: profile initialization, reuse, quoting, and rejection\n'
