# Security boundaries

This repository is public configuration, not a secret store. It contains generic source templates and examples. Local account profiles, rendered author data, credentials, and backups belong outside the checkout. A GitHub username or hostname is not inherently a credential, but user-specific account and organization details are not public defaults in this project.

Never commit private SSH keys, personal access tokens, OAuth credentials, GitHub CLI authentication files, Keychain exports, credential helpers' stores, sensitive environment files, or logs. Also exclude private project contents, student submissions, grading or teaching resources, employer materials, and any confidential organizational content. Encryption is not an excuse to commit such material here.

Ignore rules are defense in depth. They do not protect files already tracked or force-added. Do not run broad `chezmoi add ~/.ssh`, `chezmoi add ~/.config`, or source imports that capture credentials. Review each addition and its desired target. Keep backups outside the source checkout.

Offline validation uses restricted shell tools and Git plumbing. It scans every index blob independently of working-tree content and checks tracked working copies for limited key/token markers. It reports entry numbers instead of matched lines, so detected values are not printed. It does not scan Git history or untracked files, discover confidential prose, validate account ownership offline, or prove all secrets are absent. Symlinks, submodules, merge stages, inaccessible content, and scanner errors require review and do not produce an overall success result.

Before publication:

- Review intended public files and `git status --short` locally. Examine staged changes and trackability of all additions; do not share raw diffs if they contain sensitive material.
- Run `bash scripts/validate.sh --publication-only`. A pass covers the reported index/working-tree scope only.
- Review untracked files you intend to add. After staging your reviewed files, rerun publication validation against the actual index. Staging and publishing remain your explicit actions.
- Scan the complete history that will be published with an independent secret scanner using its current official instructions, for example [Gitleaks](https://github.com/gitleaks/gitleaks). This is an optional, separately installed review tool, not a default runtime dependency. Confirm the scan scope includes all branches/tags you intend to publish.
- Review history, names, documentation, logs, and binary files manually for organizational confidentiality and user-specific data; patterns cannot identify all such material.
- Confirm no private repository, credentials, student work, employer materials, or secret-bearing backup has entered the repository or its history.
- Review included workflow/prompt files as public content, then publish only after you decide the reviewed scope is appropriate.

If a secret is discovered, stop publication. Revoke/rotate the credential through the relevant service before relying on deletion. Removing a working file or adding an ignore rule does not remove index blobs, history, forks, or cached copies. Follow the hosting service's sensitive-data-removal procedure and inspect all publishable references. Do not paste secrets into an issue, chat, or validation logs.

Credential generation and optional Keychain enrollment require explicit approval per selected key in the guided runner. Key replacement and public-key registration remain manual actions. The runner requires nonempty passphrases for new keys and stops for browser registration. It never accepts blanket unattended consent. The configuration and offline validator do not perform them. Explicit connectivity checks can contact servers and affect normal SSH agent/Keychain state; keep normal host verification and verify fingerprints using a trusted source.
