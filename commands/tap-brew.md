---
description: Publish the project in the current working directory to a personal Homebrew tap (homebrew-*).
argument-hint: "[tap-owner/homebrew-tap] [--tag vX.Y.Z]"
---

Run the `tap-brewer` skill workflow defined in `SKILL.md` for the project in the current working directory.

Optional user arguments: `$ARGUMENTS`

Follow all five workflow steps strictly:
1. Preflight `gh` auth and discover or select the target `homebrew-*` tap repository into `/tmp/tap-brewer-work/<tap-name>`.
2. Analyze CWD manifests and fetch the release tarball URL and SHA256 using `scripts/fetch_release_info.sh`. Stop if no GitHub release exists.
3. Generate or update `Formula/<name>.rb` from `templates/` following `brew audit --strict`.
4. Update the tap `README.md` table via `scripts/refactor_tap_readme.py`, re-document the tap repo with `well-document` if installed, and validate with `brew style`.
5. Show `git diff --stat`, the formula, and documentation diffs, then wait for explicit user confirmation before committing or pushing.
