# mac-dotfiles contributor guidance

- Keep Homebrew manifests, chezmoi source, workstation bootstrap, and the
  optional HomeOps installer in this repository.
- Keep HomeOps CLI behavior, application configuration, reports, cleanup state,
  tests, packaging, and releases in the HomeOps repository.
- Do not run the HomeOps installer from chezmoi hooks.
- Keep credentials, usernames, device identifiers, runtime reports, cleanup
  plans, and local configuration out of tracked source.
- Treat the existing multi-root VS Code workspace as an editing convenience;
  do not recreate or replace it from repository scripts.
- Validate shell changes with the repository's native checks and preserve
  independent Git histories.
