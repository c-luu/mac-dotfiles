#!/bin/zsh -f
# Conservative lexical inspection only. Never eval configuration text.
setopt NO_UNSET
alias_name=${1:l}
ssh_home=$2
shift 2
active=1
keychain=''
typeset -A visiting
inspect() {
    local cfg_path=$1 depth=$2 line token directive pattern candidate negate hit rejected
    local -a tokens patterns matches
    (( depth < 32 )) || return 1
    cfg_path=${cfg_path:A}
    [[ -r $cfg_path && -f $cfg_path && -z ${visiting[$cfg_path]-} ]] || return 1
    visiting[$cfg_path]=1
    while IFS= read -r line || [[ -n $line ]]; do
        # Decline continuations and unsupported shell-like substitutions.
        [[ $line != *'\' ]] || return 1
        tokens=(${(z)line})
        (( ${#tokens} )) || continue
        [[ ${tokens[1]} != \#* ]] || continue
        # Accept whitespace form only; ambiguous '=' syntax requires review.
        directive=${tokens[1]:l}
        [[ $directive != *'='* ]] || return 1
        case $directive in
            match|proxycommand|localcommand|knownhostscommand|remotecommand) return 1 ;;
            canonicalizehostname)
                [[ ${tokens[2]-} == no || ${tokens[2]-} == false ]] || return 1 ;;
            host)
                active=0; hit=0; rejected=0
                for token in "${tokens[@]:1}"; do
                    [[ $token != \#* ]] || break
                    pattern=${(Q)token}; pattern=${pattern:l}
                    negate=0
                    if [[ $pattern == '!'* ]]; then negate=1; pattern=${pattern#'!'}; fi
                    [[ $pattern != *'['* && $pattern != *'('* && $pattern != *'|'* ]] || return 1
                    if [[ $alias_name == ${~pattern} ]]; then
                        if ((negate)); then rejected=1; else hit=1; fi
                    fi
                done
                (( hit && ! rejected )) && active=1
                ;;
            include)
                for token in "${tokens[@]:1}"; do
                    [[ $token != \#* ]] || break
                    pattern=${(Q)token}
                    [[ $pattern != *'$'* && $pattern != *'%'* && $pattern != *'`'* && $pattern != *'('* && $pattern != *'['* ]] || return 1
                    if [[ $pattern == '~/'* ]]; then pattern="$ssh_home/${pattern#'~/'}"; fi
                    [[ $pattern == /* ]] || pattern="$ssh_home/.ssh/$pattern"
                    matches=(${~pattern}(N))
                    if (( ! ${#matches} )); then
                        [[ $pattern == *'*'* || $pattern == *'?'* ]] || return 1
                    fi
                    # Inspect inactive include graphs too, without applying their scope.
                    local saved_active=$active saved_keychain=$keychain
                    for candidate in "${matches[@]}"; do inspect "$candidate" $((depth+1)) || return 1; done
                    if (( ! saved_active )); then active=$saved_active; keychain=$saved_keychain; fi
                done
                ;;
            usekeychain)
                if ((active)) && [[ -z $keychain ]]; then
                    (( ${#tokens} >= 2 )) || return 1
                    keychain=${tokens[2]:l}
                fi
                ;;
        esac
    done < "$cfg_path"
    unset 'visiting[$cfg_path]'
    return 0
}
for cfg_path in "$@"; do inspect "$cfg_path" 0 || exit 1; done
print -r -- "$keychain"
