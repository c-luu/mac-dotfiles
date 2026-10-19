# mac-dotfiles

Declarative user configuration for Apple Silicon macOS. Git author identities follow configurable repository directories. SSH profiles select accounts on shared hosts, including GitHub.com and GitHub Enterprise. Account names, enterprise endpoints, keys, and author emails are local inputs.

The repository uses chezmoi, Homebrew Bundle, Git, and Apple OpenSSH. Configuration deployment does not provision credentials or manage existing Git/SSH entrypoints automatically. The optional guided runner asks before each credential action.

New to this setup? Follow the [beginner walkthrough](docs/README-beginner.md) for generic, optional account profiles and the interactive `./scripts/beginner/setup.sh` runner, with explanations of what each command does, why it is needed, and which actions change local or remote state.

## New Mac setup

Homebrew must already be installed and available as `brew` in your terminal. CLI editing uses Vim.

Acquire this public repository over HTTPS using Git and your chosen public repository URL; SSH credentials are not needed. Enter the checkout before running repository commands. Then install only the default tools:

```sh
brew bundle install --no-upgrade --file=Brewfile
```

Optional GitHub CLI is a separate selection:

```sh
brew bundle install --no-upgrade --file=Brewfile.gh
```

HomeOps is an optional Android operations CLI. Select its separate
prerequisites only when needed:

```sh
brew bundle install --no-upgrade --file=Brewfile.homeops
./scripts/install-homeops.sh
```

The installer uses `uv tool` and the reviewed immutable commit in
`homeops-version`; it does not require a HomeOps source checkout. A matching
installation is left untouched. A mismatch is reported and requires explicit
approval before replacement:

```sh
./scripts/install-homeops.sh --upgrade
```

HomeOps-specific installation is never run by chezmoi. Developers should use
HomeOps' own checkout and development environment separately from this
end-user CLI installation. To roll back, review and replace the declared
commit, then run the installer with `--upgrade`; unrelated Homebrew packages
are not uninstalled.

The existing VS Code multi-root workspace is only an editing convenience. It
opens `homeops` and `../mac-dotfiles` as independent repositories relative to
the workspace file. On another Mac, place the two checkouts as siblings and
recreate an equivalent workspace manually if desired; do not use the workspace
as a deployment system. HomeOps owns its application configuration, local
reports, cleanup state, tests, and releases. This repository owns workstation
bootstrap, Homebrew, chezmoi, and the HomeOps installer.

These operations install missing dependencies without requesting upgrades or explicitly uninstalling unlisted packages. Homebrew's normal automatic cleanup remains enabled. Homebrew remains a rolling package manager, so manifests do not pin exact versions. See [Bundle documentation](https://docs.brew.sh/Brew-Bundle-and-Brewfile) and [cleanup controls](https://docs.brew.sh/FAQ). There are no package hooks in chezmoi.

Next create/edit local profiles, preview and apply fragments, integrate includes, and run offline validation. Provision keys separately only if needed. Invoke network authentication checks explicitly at the end.

## Source and local state

`.chezmoiroot` limits source state to `home/`. Only files under `home/` are deployed; documentation, scripts, and Brewfiles stay in the checkout. `examples/profiles.toml` is an incomplete example, not a working identity: replace every `REPLACE_ME` and remove profiles you do not need.

Keep local configuration at `~/.config/chezmoi/chezmoi.toml`, outside the checkout. Each profile contains independent author details, literal repository roots, alias, hostname, port, SSH user, existing key path, and expected authenticated account. Author names can contain spaces and quotes. Aliases/hostnames/users/account names use letters, digits, dots, underscores, or hyphens; aliases are unique ignoring case. Roots must not overlap across profiles, including through path aliases. Profiles do not infer emails from their SSH accounts.

Initialization validates and reuses the local profile registry. Back up an existing chezmoi config before initialization; the config template retains the registry and generates a minimal `[data]` configuration. If you have other chezmoi options, preserve them in the backup and restore the options after reviewing the generated config. Do not import the config into source control.

## Preview and deployment

After installing prerequisites and acquiring source (see below), copy the example to your local chezmoi config only if that path is unused; otherwise merge the tables manually. Edit it locally. Never put credentials in it.

```sh
chezmoi --source "$PWD" init
chezmoi --source "$PWD" managed
chezmoi --source "$PWD" diff
chezmoi --source "$PWD" apply --dry-run --verbose
```

Preview changes and back up any target collisions outside the checkout. Apply is a separate local configuration action:

```sh
chezmoi --source "$PWD" apply
```

Integration of the managed Git/SSH fragments requires explicit include edits described below. Applying files alone does not make the includes active. Chezmoi manages only the fragments and their parent directory permissions; it preserves unrelated directory contents. SSH directories become 0700, private managed files 0600.

Inspect drift without overwriting it:

```sh
chezmoi --source "$PWD" diff
chezmoi --source "$PWD" verify
```

`verify` returns nonzero when target state differs. Review before reapplying. Never use a force flag to hide unexplained changes.

## Ownership

| Target | Ownership |
|---|---|
| `~/.config/git/mac-dotfiles.inc` | Managed routing; no default author |
| `~/.config/git/<profile-id>.inc` | Managed per-profile author |
| `~/.ssh/config.d/mac-dotfiles.conf` | Managed SSH profiles |
| `~/.gitconfig`, `~/.config/git/config`, `~/.ssh/config` | User-owned include integration |
| `~/.config/chezmoi/chezmoi.toml` | Local registry; initialization can rewrite it |
| Private keys, known-host records, Keychain | User-owned credentials/state |

Git and SSH parent directories are shared; do not remove them wholesale during recovery or removal.

## Git integration

Back up and inspect both `~/.gitconfig` and `~/.config/git/config` if present. Git can read both; `git config --global --show-origin --list` shows the active sources. On a fresh setup a missing `~/.gitconfig` error means you can create it in Vim and add the include below. Review locally since this output can include private configuration. Add this once to the appropriate global file:

```gitconfig
[include]
    path = ~/.config/git/mac-dotfiles.inc
```

Review existing unconditional `user.name`, `user.email`, `author.*`, or `committer.*` values in every global/system include. Remove conflicting defaults only after reviewing their origins; the project will not remove them. `user.useConfigOnly` stops guessed identities but cannot erase explicit inherited authors. Local repository settings and `GIT_AUTHOR_*`, `GIT_COMMITTER_*`, or `EMAIL` environment variables can override directory identities; inspect those when attribution differs.

Conditional includes match each profile's literal Git-directory root recursively. A repository outside those roots must configure its identity explicitly. Linked worktrees and submodules follow the resolved Git directory, which can differ from the checkout location; review their identity explicitly. Do not assume moving a worktree changes its author.

Adding another profile requires local registry data and a public-safe source entry in `home/dot_config/private_git/private_<id>.inc.tmpl`:

```gotemplate
{{ includeTemplate ".chezmoitemplates/git-author" (dict "id" "new-profile" "data" .) }}
```

Use a generic ID and the matching filename. The shared author template reads real values locally. Generic `account-a`, `account-b`, and `enterprise` entries are provided and ignored when their local profiles are absent. For a custom source entry absent locally, remove it or add its target to `.chezmoiignore`; do not invent placeholder authors to make it render.

## SSH integration and credentials

Back up `~/.ssh/config` outside the source checkout. Add this at top level near the beginning, before conflicting defaults, outside a `Host` or `Match` block:

```sshconfig
Include ~/.ssh/config.d/mac-dotfiles.conf
```

Review existing blocks matching these aliases. OpenSSH generally uses the first value it obtains, but `IdentityFile` accumulates across matching blocks: `IdentitiesOnly yes` does not fix an extra wildcard key. Adjust only conflicting settings after review. The fragment resets scope with `Host *`; unrelated host definitions remain yours.

Use a configured alias in a remote, for example `git@github-account-a:example-owner/example-project.git`. On an enterprise endpoint with a custom port, the alias selects its configured port. Changing a remote is a deliberate repository operation; deployment never rewrites remotes.

Git author identity, SSH authentication, GitHub CLI login, and Copilot/application login are independent. Directory routing selects an author; an SSH alias selects a key; application login selects entitlements. No account logout is required to alternate SSH profiles. Configure application logins manually if desired.

Credential provisioning is a separate user-approved action. The guided runner offers per-key creation and optional enrollment; replacement and browser registration remain manual:

1. Review existing keys and profile paths without displaying private-key contents. Reuse an appropriate key or choose an unused path. Never replace a key simply because setup reports it missing.
2. If you choose to generate a key, run `ssh-keygen` manually for that unused path, choose a passphrase, and confirm no file is overwritten. The guided runner can invoke key generation only after approval for that profile; deployment and validators never invoke it.
3. Enroll a passphrase manually with Apple's `/usr/bin/ssh-add --apple-use-keychain <existing-key-path>` when desired. Enrollment changes your agent/Keychain independently of deployment. For an unencrypted key, use ordinary `/usr/bin/ssh-add` instead.
4. Register only the public key with the intended GitHub.com or Enterprise account through that service's account settings. Review organization policy where applicable. Never upload the private key.

Use `/usr/bin/ssh` and `/usr/bin/ssh-add`, not replacement Homebrew SSH binaries, for Apple's Keychain extensions. Deployment only references key paths; it does not enroll keys, authenticate accounts, or register credentials. See [GitHub's macOS SSH setup guidance](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent?platform=mac).

## Offline validation

Run preflight before applying, then validate deployed state after integrating includes:

```sh
bash scripts/validate.sh --preflight
bash scripts/validate.sh
bash scripts/validate.sh --repository /absolute/path/to/a/repository
```

Preflight validates local profiles, source entry completeness, dependencies, and publication checks; it does not require deployed files or provisioned keys. Deployed validation also checks permissions, key-file existence through metadata only, SSH effective routing, deployed Git fragments against rendered source, active global Git integration, and fallback authors.

Git directory routing is exercised in disposable temporary repositories with remapped roots, including nested directories and an unmanaged repository. This never creates repositories under your configured roots. Actual local overrides are inspected only for the repository you explicitly select with `--repository`; its effective author values and configuration origins are reported locally. General validation does not inspect every real project. Keep local identity diagnostics private if appropriate.

The SSH safety gate declines executable directives, `Match` blocks, unresolved includes, unsupported syntax, and hostname canonicalization before invoking `ssh -G`. Review those settings manually; a declined check is incomplete, not a pass. Apple SSH omits `UseKeychain` from `-G` output, so the gate checks its first applicable directive and native parsing accepts the configuration. No host connection, agent enrollment, permission repair, deployment, or package installation occurs.

Exit 0 means requested checks completed successfully; exit 1 indicates failure or an incomplete required check; exit 2 indicates invalid command options. Results use `PASS`, `FAIL`, `NOT_PERFORMED`, and `CREDENTIAL_MISSING` categories, plus informational scope messages. Missing keys are separate credential prerequisites: deploy configuration first if desired, provision credentials manually later, then rerun deployed validation. All temporary state is removed on exit.

Use `--source`, `--config`, `--destination`, and `--checkout` for explicit alternate locations. `--ssh-config` selects a standalone SSH graph for isolated testing and omits system SSH configuration; normal deployed checks include the system graph. Publication-only mode needs neither local profiles nor chezmoi. No mode contacts GitHub.

## Explicit connectivity checks

Network authentication is separate from offline validation:

```sh
bash scripts/check-connectivity.sh
```

The checker runs Apple's `ssh -T` for each configured profile, checks the locally expected account, and reports authentication success even when GitHub exits 1 because it denies shell access. Wrong accounts, authentication failures, timeouts, host-verification failures, and unfamiliar enterprise responses are distinct failures. Unfamiliar responses are inconclusive, not guessed successes.

The checker uses batch authentication and strict host verification. Review server fingerprints through a trusted service/organization source before accepting a host with a separate manual SSH connection. Never disable host verification to make a check pass. First-use verification and agent/Keychain effects are explicit network-action concerns. Configuration preview and offline validation do not contact these hosts or modify account/repository state.

## Maintenance and recovery

To add an account, add a local profile with a unique alias and non-overlapping directory roots, then add its generic source entry using the shared author template described above. Preview the new targets before applying. To remove a profile, review/remove its source entry and local table together; remove its deployed author fragment manually only after checking the ownership map. Chezmoi does not delete forgotten fragments automatically.

To change an SSH key, update only that profile's `identityFile`, preview the changed reference, and apply. Provision or register the replacement key separately and retain the previous key until you have verified the new authentication path. Deployment never moves or deletes either key.

To add packages, edit the chosen Brewfile, review it, and explicitly run the documented Bundle installation command with cleanup disabled. Do not use cleanup or autoremove to converge the whole Mac. Keep optional tools in an explicitly selected manifest.

To update managed configuration, edit the source templates, review `chezmoi diff`, and apply only after inspection. To acquire upstream changes, review the source Git diff before pulling or applying. Prefer a separate Git pull and chezmoi preview/apply sequence; `chezmoi update` can pull and apply together, so do not use it when you need review in between. Review drift with `diff` and `verify`; choose deliberately whether to retain a local edit by updating source or restore desired state by applying.

For a failed or partial apply, stop and inspect `chezmoi diff` and the listed managed paths. Restore any collided targets from your local backups, repair only the reviewed include conflicts, and preview again before retrying. Includes are user-owned and must be restored separately from fragments. Never restore by replacing entire `.ssh` or Git configuration directories.

To disengage management, you can stop running chezmoi and leave deployed configuration intact. To remove managed configuration, first remove only the explicit include directives you added, inspect each owned fragment, restore backed-up collisions where appropriate, and then remove only selected managed fragments. Preserve keys, known-host records, unrelated configuration, directories shared with other tools, and packages. Removing chezmoi or Homebrew packages is a separate user-selected action, not a recovery requirement. Avoid `chezmoi purge`, broad recursive deletion, and package cleanup as an uninstall recipe.

## Public publication

Review [SECURITY.md](SECURITY.md) and its checklist. Publication validation is an explicitly invoked local action:

```sh
bash scripts/validate.sh --publication-only
```

This checks the index and available tracked working copies. Review untracked additions and history separately, stage only reviewed content yourself, and rerun before publishing. Passing limited pattern checks does not prove the absence of secrets or confidential information. Publication is never automated by this repository.

## Development checks

Run fixture tests with an installed chezmoi, or set `CHEZMOI` to an explicitly chosen test binary. Fixtures use temporary source/config/target locations and no real keys or account connections. They do not deploy to your home directory. Tests requiring routing inspection use Git repositories only inside their temporary fixture directories.

```sh
bash tests/run.sh
```
