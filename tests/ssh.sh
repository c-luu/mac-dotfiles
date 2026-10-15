#!/bin/bash
source "$(dirname "$0")/lib.sh"
profile account-a github-account-a github.com
profile account-b github-account-b github.com
profile enterprise git-enterprise github.example.com 2222
cm apply
printf 'Include "%s"\nHost unrelated\n HostName example.org\n User other\n' "$FIXTURE/target/.ssh/config.d/mac-dotfiles.conf" > "$FIXTURE/ssh-config"
for pair in 'github-account-a account-a github.com 22' 'github-account-b account-b github.com 22' 'git-enterprise enterprise github.example.com 2222'; do
    read -r alias id host port <<< "$pair"
    /usr/bin/ssh -G -F "$FIXTURE/ssh-config" "$alias" > "$FIXTURE/effective" 2>/dev/null
    for expected in "hostname $host" "user git" "port $port" "identityfile $FIXTURE/keys/$id" 'identitiesonly yes' 'addkeystoagent true'; do
        /usr/bin/grep -qxF "$expected" "$FIXTURE/effective" || fail "SSH setting: $expected"
    done
done
[[ $(/usr/bin/grep -c '    UseKeychain yes' "$FIXTURE/target/.ssh/config.d/mac-dotfiles.conf") == 3 ]] || fail 'Keychain declaration'
printf 'PASS: shared-host and custom-port enterprise SSH profiles\n'
/usr/bin/ssh -G -F "$FIXTURE/ssh-config" unrelated > "$FIXTURE/unrelated" 2>/dev/null
/usr/bin/grep -qxF 'user other' "$FIXTURE/unrelated" || fail 'include scope leaked'
/usr/bin/grep -qxF 'hostname example.org' "$FIXTURE/unrelated" || fail 'unrelated host changed'
printf 'Host *\n IdentityFile /tmp/extra-key\n' >> "$FIXTURE/ssh-config"
/usr/bin/ssh -G -F "$FIXTURE/ssh-config" github-account-a > "$FIXTURE/extra" 2>/dev/null
[[ $(/usr/bin/grep -c '^identityfile ' "$FIXTURE/extra") == 2 ]] || fail 'additive key fixture'
printf 'Host github-account-a\n User wrong\nInclude "%s"\n' "$FIXTURE/target/.ssh/config.d/mac-dotfiles.conf" > "$FIXTURE/conflict"
/usr/bin/ssh -G -F "$FIXTURE/conflict" github-account-a > "$FIXTURE/conflict-effective" 2>/dev/null
/usr/bin/grep -qxF 'user wrong' "$FIXTURE/conflict-effective" || fail 'first value fixture'
printf 'PASS: scope, unrelated host, additive keys, first-value conflict\n'
