# Roadmap

This roadmap tracks planned milestones for `tap-brewer`. Items are grouped by release target and reflect concrete repository scope.

## v0.1.0 (Initial Release)

- Core 5-step Homebrew publishing workflow in `SKILL.md`.
- Deterministic GitHub release fetcher and SHA256 calculator in `scripts/fetch_release_info.sh`.
- Zero-dependency tap `README.md` table updater in `scripts/refactor_tap_readme.py`.
- `brew style` verified formula templates for Python, Go, Node.js, and Shell.
- Automated `unittest` suite and GitHub Actions CI.

## v0.2.0 (Ecosystem Expansion)

- Dedicated `templates/rust.rb.tmpl` template using `std_cargo_args` with CI `brew style` coverage.
- Support for multi-binary formulas and shell completion installation stanzas (`generate_completions_from_executable`).
- Optional `--check` mode in `scripts/refactor_tap_readme.py` to detect unsorted or out-of-sync tap tables.

## v0.3.0 (Release Automation Helpers)

- Support for Homebrew Cask templates for macOS `.dmg` and `.zip` release assets.
- Optional support for pre-release tags and multi-architecture binary tarballs (`on_macos` / `on_linux`, `on_arm` / `on_intel`).
