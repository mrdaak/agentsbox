# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

### Fixed

- Give plain terminal panes a readline-capable shell, restoring command
  history and tab completion.

## [0.2.1] - 2026-08-27

### Changed

- Rename the `update` command to `rebuild`.
- Bake bundled skills into the image at build time; sessions no longer copy
  them over the network at startup.
- Disable the Codex update banner.

### Removed

- Remove the `install-skills` command (skills are now baked into the image).

## [0.2.0] - 2026-08-26

### Added

- Add the `upgrade` command to move a pinned install to the latest tag.
- Document the Determinate Nix Installer for macOS.

### Fixed

- Fix the `--web` session.

[Unreleased]: https://github.com/mrdaak/agentsbox/compare/v0.2.1...HEAD
[0.2.1]: https://github.com/mrdaak/agentsbox/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/mrdaak/agentsbox/releases/tag/v0.2.0