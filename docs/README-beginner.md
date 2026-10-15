# Beginner setup: Git and SSH account profiles

This guide uses generic examples for two GitHub.com profiles and an optional Enterprise profile. Keep only the profiles you need. Replace example account names, author values, paths, and the Enterprise hostname with your own values in local configuration outside the checkout. Existing local profiles and keys do not need to be renamed.

For guided setup, review and run:

```sh
./scripts/beginner/setup.sh
```

The runner follows steps 2–10 below and pauses before changes. It uses Vim for local configuration and include edits; it asks separately for each missing SSH key, public-key clipboard copy, optional Keychain enrollment, and server connection. Blank input never approves a change. Choose stop or press Control-C to stop; already completed changes remain. Rerun to inspect current state and continue with fresh approvals. Skipped network checks leave connectivity unverified. Cloning and maintenance remain separate follow-up actions.

Follow the steps in order, running one command at a time. This document is an instruction guide: opening it does not run anything. Multi-command workflows live in `scripts/beginner/` as runnable Bash scripts; review a script before running it. Commands marked **local change**, **package installation**, **credential change**, or **network action** require you to deliberately run them. Preview and validation commands inspect configuration rather than deploy it.

## Understand the three kinds of identity

| Concern | What selects it | What it controls |
|---|---|---|
| Git commit author | Repository location and profile author fields | Name and email recorded in new commits |
| SSH authentication | Alias in the repository's SSH remote URL | Account whose key is presented to the server |
| Copilot or other application login | Sign-in within the application | Application access and account entitlements |

A commit email does not log you into GitHub. An SSH key does not choose your commit author. Signing into Copilot does not change either setting. This setup lets SSH accounts coexist without logging out to switch keys.

We will use the existing generic profile IDs so no new source files are needed:

| Profile ID | Account | SSH alias | Repository root | Key path |
|---|---|---|---|---|
| `account-a` | `example-account-a` on GitHub.com | `github-account-a` | `~/Developer/account-a/` | `~/.ssh/account-a` |
| `account-b` | `example-account-b` on GitHub.com | `github-account-b` | `~/Developer/account-b/` | `~/.ssh/account-b` |
| `enterprise` | `example-account-b` on Enterprise | `git-enterprise` | `~/Developer/enterprise/` | `~/.ssh/enterprise` |

The profile IDs identify templates; the SSH aliases are local nicknames. You can change directory names, aliases, or key paths in your local configuration. The hostname remains the actual server address.

Your projects live under `~/Developer`. This walkthrough uses three account folders within it: `account-a/`, `account-b/`, and `enterprise/`. Your dotfiles checkout stays at `~/Developer/mac-dotfiles`; it does not need to move. These folder names are a suggested organization, not a requirement.

## 1. Open Terminal and enter the checkout

```sh
cd ~/Developer/mac-dotfiles
```

`cd` changes your terminal's current working directory to the checkout containing this project's `Brewfile`, `home/`, and `scripts/`. If your checkout is elsewhere, substitute that location for `~/Developer/mac-dotfiles`.

A path starting with `~` refers to your home folder. `$PWD` means your current working directory. Quotes around `"$PWD"` keep the path together if it contains spaces. Later chezmoi commands use `--source "$PWD"` to explicitly select this checkout instead of assuming chezmoi's default source location.

If you have not acquired the repository yet, clone its public HTTPS URL with Git and enter that checkout. HTTPS acquisition of public source does not require your SSH keys. Use the actual repository URL you intend to manage.

## 2. Install the project tools

This guide assumes Homebrew is already installed and `brew` is available in your terminal.

From the checkout, perform this **package installation**:

```sh
brew bundle install --no-upgrade --file=Brewfile
```

- `brew bundle install` installs dependencies declared in a manifest.
- `--file=Brewfile` selects this repository's list: Git and chezmoi, plus required transitive dependencies.
- `--no-upgrade` suppresses Bundle's request to upgrade already-installed tools.

The manifest does not remove other software or pin exact versions. Homebrew's normal automatic cleanup remains enabled. See [Homebrew Bundle documentation](https://docs.brew.sh/Brew-Bundle-and-Brewfile).

Optional GitHub CLI is a separate package choice:

```sh
brew bundle install --no-upgrade --file=Brewfile.gh
```

This selects the optional `gh` manifest. You can skip it; the setup and validators do not require GitHub CLI login.

## 3. Back up existing configuration

This **local change** creates a private backup directory outside the checkout and copies each existing configuration file:

```sh
./scripts/beginner/backup-config.sh
```

The script backs up `~/.config/chezmoi/chezmoi.toml`, `~/.gitconfig`, `~/.config/git/config`, and `~/.ssh/config` into `~/mac-dotfiles-backups`. It skips missing files, restricts the backup directory to your user, and preserves file metadata. It asks before overwriting an existing backup; decline if the older backup is still needed. To use a different backup directory, pass its path as the script's argument. The script does not remove originals or copy private keys.

Later, also back up any existing managed target that the preview shows would be replaced. The main [ownership map](../README.md#ownership) identifies those targets.

## 4. Create your local account profiles

These **local changes** create the configuration directory and open the local file in Vim, the assumed CLI editor throughout this guide:

```sh
./scripts/beginner/edit-profiles.sh
```

If the file is empty, paste the following content, removing any profiles you do not need. `git.example.com` in prose is a reserved example, not an actual Enterprise service; replace the Enterprise hostname placeholder with your server. If it already has configuration, merge the tables carefully rather than deleting unrelated settings. Do not create duplicate `[data.profiles...]` tables.

```toml
[data.profiles.account-a]
authorName = "REPLACE_ME"
authorEmail = "REPLACE_ME"
repositoryRoots = ["~/Developer/account-a"]
sshAlias = "github-account-a"
hostname = "github.com"
port = 22
sshUser = "git"
identityFile = "~/.ssh/account-a"
expectedAccount = "REPLACE_ME"

[data.profiles.account-b]
authorName = "REPLACE_ME"
authorEmail = "REPLACE_ME"
repositoryRoots = ["~/Developer/account-b"]
sshAlias = "github-account-b"
hostname = "github.com"
port = 22
sshUser = "git"
identityFile = "~/.ssh/account-b"
expectedAccount = "REPLACE_ME"

[data.profiles.enterprise]
authorName = "REPLACE_ME"
authorEmail = "REPLACE_ME"
repositoryRoots = ["~/Developer/enterprise"]
sshAlias = "git-enterprise"
hostname = "REPLACE_ME"
port = 22
sshUser = "git"
identityFile = "~/.ssh/enterprise"
expectedAccount = "REPLACE_ME"
```

In Vim, press `i` to enter Insert mode before typing or pasting. Replace **every** `REPLACE_ME` before continuing, including `expectedAccount` and the optional Enterprise hostname. Press Escape, type `:wq`, and press Enter to save and exit. To exit without saving, press Escape, type `:q!`, and press Enter.

| Field | Meaning and reason |
|---|---|
| `authorName` | Your desired commit author name; usually your name, not your login username |
| `authorEmail` | The email you want recorded in commits for this profile; select it independently per account |
| `repositoryRoots` | An array of directories whose repositories receive this author, including nested repositories |
| `sshAlias` | A unique nickname that lets different accounts share a server without sharing key selection |
| `hostname` | The actual server; use `git.example.com`, with no `https://` or trailing slash |
| `port` | The SSH endpoint's port; 22 is assumed here, but use the port specified by the Enterprise SSH clone instructions |
| `sshUser` | The SSH transport user; GitHub uses `git` while the key identifies your account |
| `identityFile` | An existing or manually provisioned private-key path; this is a reference, not the key contents |
| `expectedAccount` | The account the connectivity checker expects the server to authenticate |

The two `example-account-b` accounts can have different author emails. Choose a verified commit email appropriate to each service; a GitHub.com noreply email is an option if supplied by that account's settings. Do not guess one from a username or assume the Enterprise email is the same.

If you already have suitable keys with other filenames, update the `identityFile` references. Do not rename or regenerate keys just to match this example. Directory roots assigned to different profiles must not overlap.

If existing projects are directly under `~/Developer`, you can keep them there. Replace the relevant profile's `repositoryRoots` with its specific project directories, for example:

```toml
repositoryRoots = ["~/Developer/mac-dotfiles", "~/Developer/another-project"]
```

This example assigns those two projects to your personal profile. Use the actual project names, and list education/Enterprise projects only in their respective profiles. Do not assign `~/Developer` to one profile while assigning its subdirectories to others: those roots overlap. Adding `~/Developer/mac-dotfiles` to your personal roots also gives this checkout your personal commit author; the suggested `~/Developer/account-a` root alone does not cover it.

This file stays in your home directory, outside the Git checkout. Do not put tokens, private keys, or passwords into it.

## 5. Initialize and inspect what would change

```sh
chezmoi --source "$PWD" init
```

This **local change** initializes chezmoi using the checkout and regenerates its local configuration from the configuration template. It validates and reuses your profile registry. It does not deploy managed target files without `--apply`. See [chezmoi init documentation](https://www.chezmoi.io/reference/commands/init/).

In this project, the template generates a minimal profile configuration. If you had other chezmoi options, compare the regenerated file with your backup and restore the options you need after review. Continue using `--source "$PWD"` for the commands in this guide.

```sh
bash scripts/validate.sh --preflight
```

`bash` runs this repository's shell validator. `--preflight` checks local inputs, matching source entries, required tools, and public-source hygiene before deployment. It does not require deployed files or provisioned keys. It installs nothing and contacts no GitHub server. Fix failed input checks before applying.

```sh
./scripts/beginner/preview.sh
```

The script runs these chezmoi commands against this checkout:

- `managed` lists target paths that chezmoi owns.
- `diff` compares desired file contents with current target contents. `+` lines represent proposed additions and `-` lines proposed removals.
- `apply --dry-run --verbose` previews deployment actions. `--dry-run` prevents target changes; `--verbose` makes the planned operations visible.

`.chezmoiroot` selects `home/` as source state. Documentation and scripts do not become home-directory dotfiles. Expect a Git routing fragment, three author fragments, and an SSH fragment. Review any replacement and back up the affected target first.

## 6. Apply the reviewed fragments

```sh
chezmoi --source "$PWD" apply
```

This **local deployment** writes the reviewed managed files. It also sets managed directory/file permissions. It does not install packages, create keys, register accounts, or modify repository remotes. It preserves unrelated directory contents.

The files are fragments: existing Git and SSH entrypoints still need explicit includes. That separation lets you retain unrelated settings rather than replace entire configuration files.

## 7. Tell Git and SSH to read the fragments

If you already have global Git configuration, inspect it locally:

```sh
git config --global --includes --show-origin --list
```

`--global` selects user-wide configuration, `--includes` reads included files too, `--show-origin` identifies where each setting came from, and `--list` prints settings. Review this output locally; credential-related settings might be present. Git can read both `~/.gitconfig` and `~/.config/git/config`.

On a fresh setup, this command may report `fatal: unable to read config file` with `No such file or directory`. That means no global configuration file exists yet; continue by creating it below.

Open the appropriate existing global file. On a fresh setup, open a new `~/.gitconfig` in Vim:

```sh
vim ~/.gitconfig
```

Add this block once, then press Escape, type `:wq`, and press Enter to save (creating the file if needed):

```gitconfig
[include]
    path = ~/.config/git/mac-dotfiles.inc
```

`include` tells Git to read the routing fragment. Its conditional includes select a per-profile author based on repository location. Review any existing unconditional `user.name`, `user.email`, `author.*`, or `committer.*` defaults and remove only conflicting defaults after checking their origins. Existing explicit defaults can defeat the no-fallback policy even when `user.useConfigOnly` is enabled.

Now open the SSH entrypoint:

```sh
vim ~/.ssh/config
```

Add this at top level near the beginning, outside any `Host` or `Match` block:

```sshconfig
Include ~/.ssh/config.d/mac-dotfiles.conf
```

SSH reads the fragment to resolve aliases into hosts, users, ports, and key paths. Preserve unrelated host settings. Earlier matching options can take precedence, and wildcard `IdentityFile` entries can add extra keys; the validator reports those conflicts.

After saving, this **local permissions change** makes the entrypoint readable/writable only by your user:

```sh
chmod 600 ~/.ssh/config
```

Create the repository roots:

```sh
mkdir -p ~/Developer/account-a ~/Developer/account-b ~/Developer/enterprise
```

These are empty organizing directories. Creating them does not clone repositories, move existing projects, or authenticate accounts.

## 8. Use a separate SSH key for each account

Run this step as your normal user; no `sudo` is needed. Keep each private key on your Mac and register only its `.pub` public key with the matching account.

Check for existing keys:

```sh
ls -la ~/.ssh
```

Reuse suitable keys and set their paths in your local profiles. Otherwise, run only the **credential creation** commands for missing keys. Both the private-key path and its `.pub` sibling must be unused; never overwrite an existing key.

```sh
/usr/bin/ssh-keygen -t ed25519 -f ~/.ssh/account-a -C "example-account-a GitHub.com"
```

```sh
/usr/bin/ssh-keygen -t ed25519 -f ~/.ssh/account-b -C "example-account-b GitHub.com"
```

```sh
/usr/bin/ssh-keygen -t ed25519 -f ~/.ssh/enterprise -C "example-account-b Enterprise"
```

Choose a strong, nonempty passphrase for each new key. `ssh-keygen` creates private keys with restrictive permissions, so newly generated keys need no extra `chmod`. Each account gets its own key so access can be revoked independently. Continue to step 9 after creating the keys you need. [GitHub SSH-key guidance](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent?platform=mac).

If the validator later reports permissions problems on a reused key you own, run `./scripts/beginner/key-permissions.sh` with only that key's path.

Explicit agent/Keychain enrollment is optional. The managed SSH configuration already enables `AddKeysToAgent` and `UseKeychain` for these aliases; an interactive SSH connection can prompt for the passphrase and cache it. To enroll a selected key before connecting, use this **credential change**:

```sh
./scripts/beginner/enroll-keys.sh ~/.ssh/account-a
```

Pass only the keys you intend to enroll. This loads the key into your SSH agent and stores its passphrase in macOS Keychain. The batch connectivity checker in step 10 cannot prompt for passphrases, so unlock the keys through an interactive connection or enrollment first. [GitHub passphrase guidance](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/working-with-ssh-key-passphrases?platform=mac).

## 9. Register each public key with the correct account

Use one clipboard command at a time, completing registration before copying the next key:

```sh
pbcopy < ~/.ssh/account-a.pub
```

`pbcopy` copies the public key into the macOS clipboard. `<` reads that file as input. The `.pub` suffix is essential: never copy/upload the private-key file.

While signed into your actual account for `account-a` on GitHub.com:

1. Open [SSH and GPG keys](https://github.com/settings/keys) in your browser (profile picture → Settings → SSH and GPG keys).
2. Click **New SSH key**.
3. Enter a **Title**, such as `My-Mac personal`.
4. Select **Authentication Key** as the **Key type**.
5. Click inside the large **Key** text box and press Command-V to paste the public key copied by `pbcopy`.
6. Click **Add SSH key** and confirm account access if prompted.

Then:

```sh
pbcopy < ~/.ssh/account-b.pub
```

Switch your browser to your actual `account-b` account on GitHub.com, then repeat the steps above at [SSH and GPG keys](https://github.com/settings/keys). Use a title such as `My-Mac education` and paste this public key into the **Key** text box. Confirm the browser account before submitting.

Finally:

```sh
pbcopy < ~/.ssh/enterprise.pub
```

While signed into your Enterprise account on your actual Enterprise hostname, open `https://YOUR_ENTERPRISE_HOST/settings/keys` (substitute your actual hostname). Click **New SSH key** (or **Add SSH key**), use a title such as `My-Mac Enterprise`, select **Authentication Key** if offered, and paste this public key into the **Key** text box. Click **Add SSH key** to submit. Browser sign-in may be required for registration; SSH routing does not require ongoing account switching afterward. Enterprise UI and organization policies can differ; follow the service's instructions. [GitHub public-key registration guidance](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account).

Registration changes the remote account. The repository never performs it automatically.

## 10. Validate offline, then connect explicitly

```sh
bash scripts/validate.sh
```

This checks deployed files, key existence/modes, SSH routing, active global Git integration, author fragments, and publication hygiene. Git routing is tested in temporary repositories with remapped roots; your real projects are not changed or searched. Key contents are not read. There is no server connection or automatic repair.

| Result | Meaning / next action |
|---|---|
| `PASS` | The named check completed successfully |
| `FAIL` | Review the reported configuration conflict or drift |
| `CREDENTIAL_MISSING` | Review the configured path, then provision the key separately if needed |
| `NOT_PERFORMED` | A required check could not be completed; review the unsupported input or missing tool |

The command exits nonzero for failure or incomplete required checks. The SSH safety gate declines executable or unsupported configuration instead of running it. An unfamiliar `Match` block can require manual review even if you use it legitimately. Publication checks cover the reported index and tracked working copies, not all history or confidential content; see [SECURITY.md](../SECURITY.md).

Next perform these interactive **network actions**. The script connects to the supplied aliases sequentially:

```sh
./scripts/beginner/connect.sh github-account-a github-account-b git-enterprise
```

You can pass a single alias to review one connection at a time. The script prints each SSH exit status and stops on statuses other than 0 or 1; read each greeting to determine whether authentication succeeded. `ssh` contacts the server selected by the alias. `git@` supplies the SSH user, and `-T` requests no interactive terminal. On first use, compare the fingerprint with a trusted GitHub/Enterprise source before accepting it; acceptance adds a host record to `known_hosts`. Never disable host verification to suppress a failure.

The first-connection fingerprint belongs to the **server**, not the account key you created in step 8. Your key proves your identity to GitHub; the server key proves GitHub's identity to your Mac. Compare GitHub.com prompts with [GitHub's published server fingerprints](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints). For `git.example.com`, use fingerprints supplied by your Enterprise administrator. Type `yes` only after the server fingerprint matches the trusted source.

Expect each greeting to identify the actual `expectedAccount` you entered for that profile. GitHub can confirm authentication and still return status 1 because it provides no shell. That is different from permission denial or a connection failure. [GitHub SSH testing instructions](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/testing-your-ssh-connection).

After trusted host records and keys are available:

```sh
bash scripts/check-connectivity.sh
```

This explicitly connects to each profile with bounded, batch-mode checks and strict host verification. It compares each recognized greeting with `expectedAccount` and distinguishes wrong accounts, authentication failures, timeouts, and unknown Enterprise responses. An unknown response is inconclusive and needs manual interpretation. No repositories are cloned or pushed by the checker.

## 11. Clone projects with the correct location and alias

Replace the example account owners, `REPOSITORY`, and Enterprise `OWNER` before running these **network/local changes**:

```sh
git clone git@github-account-a:example-account-a/REPOSITORY.git ~/Developer/account-a/REPOSITORY
```

```sh
git clone git@github-account-b:example-account-b/REPOSITORY.git ~/Developer/account-b/REPOSITORY
```

```sh
git clone git@git-enterprise:OWNER/REPOSITORY.git ~/Developer/enterprise/REPOSITORY
```

`git clone` downloads a repository and creates a local checkout. The alias selects the authentication key; the destination selects the commit author. Enterprise `OWNER` could be an organization rather than your username. Use an actual repository you are authorized to access.

For an existing project, inspect first:

```sh
git -C ~/Developer/account-a/REPOSITORY remote -v
```

`-C` runs Git in that directory without changing your shell's working directory. `remote -v` prints the configured fetch/push URLs without contacting a server. Keep private repository details local. HTTPS remotes do not use these SSH aliases.

If you deliberately want to change this project's `origin` to the personal SSH route:

```sh
git -C ~/Developer/account-a/REPOSITORY remote set-url origin git@github-account-a:example-account-a/REPOSITORY.git
```

This changes that repository's local remote URL, not the remote server. Review the existing URL before replacing it. Use the education or Enterprise alias/owner for those projects. Directory rules do not automatically move projects or rewrite their remotes.

Inspect the effective author for one explicitly selected repository:

```sh
bash scripts/validate.sh --repository ~/Developer/account-a/REPOSITORY
```

This runs local validation and reports that repository's author values and their configuration origins. It detects conflicting local author settings and relevant environment overrides without modifying them. Linked worktrees/submodules can have a Git directory outside the checkout root, so inspect their authors explicitly.

## 12. Maintain and recover the configuration

```sh
./scripts/beginner/check-drift.sh
```

The script runs `chezmoi diff` followed by `chezmoi verify` against this checkout. `diff` shows drift; `verify` returns nonzero when target state differs from desired state. These commands do not overwrite deployed files. After reviewing a source/local-profile change and the diff, `chezmoi --source "$PWD" apply` reapplies it. Reapplying unchanged inputs should produce no new changes.

Edit real account values in the local registry; edit reusable behavior in source templates. Preview both kinds of change. Adding a differently named profile needs a matching generic author source entry; consult the [main README](../README.md#git-integration).

If an apply fails, inspect the affected owned targets and restore only needed files from your backups, then preview again. Includes in your Git/SSH entrypoints are user-owned and require separate review. Keep private keys and unrelated configuration intact. Do not use recursive deletion, package cleanup, or a force flag as a substitute for understanding a conflict.

For Copilot, manually sign into the intended account in your editor. That does not replace any Git/SSH setup step above.

For removal, updates, publication review, and additional profiles, continue with the [main README](../README.md) and [security boundaries](../SECURITY.md). This guide's commands describe setup you choose to perform; implementation fixture tests did not provision your actual Mac or accounts.
