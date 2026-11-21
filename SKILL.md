---
name: tap-brewer
description: >
  Publish the project in the current working directory to a personal Homebrew tap
  repository (homebrew-*). Fetches GitHub release tarballs and SHA256 checksums,
  generates or updates brew-audit-compliant Ruby formulas, refactors the tap
  README.md package table, validates with brew style/audit, and commits after review.
  Use when the user asks to publish, release, ship, or update a Homebrew formula
  or tap from the current project.
---

# tap-brewer

Publish the project in the current working directory (CWD) to a personal Homebrew tap repository (`homebrew-*`), update the tap `README.md` table, and validate the generated formula before committing.

## Hard Constraints

- Never modify files, tags, or git state in the user's CWD repository unless explicitly asked.
- Never force-push (`git push --force` or `--force-with-lease`) to any tap repository.
- Never guess tarball URLs or SHA256 hashes. Always compute them with `scripts/fetch_release_info.sh`.
- Always show the diff and wait for explicit user confirmation before committing or pushing.

## Workflow

Execute these five steps in order. Resolve helper script and template paths relative to this skill's directory.

### 1. Preflight and Tap Discovery

1. Verify GitHub CLI authentication:
   ```bash
   gh auth status
   ```
   Stop and instruct the user to run `gh auth login` if authentication fails or `gh` is missing.
2. Locate the target tap repository if the user did not specify one:
   ```bash
   gh repo list --limit 100 --json nameWithOwner --jq '.[] | select(.nameWithOwner | test("/homebrew-")) | .nameWithOwner'
   ```
   - If exactly one `homebrew-*` repository is returned, select it automatically and report the choice.
   - If multiple repositories are returned, list them and ask the user to choose one.
   - If none exist, stop and tell the user to create a `homebrew-<name>` repository first.
3. Prepare the working copy in `/tmp/tap-brewer-work/<tap-repo-name>` (for example, `/tmp/tap-brewer-work/homebrew-tap`):
   - If the directory does not exist, clone the repository with `gh repo clone <owner>/<tap-repo> /tmp/tap-brewer-work/<tap-repo-name>`.
   - If the directory already exists, verify `git status --porcelain` is empty. If dirty, stop and ask the user how to proceed. If clean, run `git pull --rebase`.

### 2. Project Analysis (CWD)

1. Detect the project ecosystem from CWD manifests:

| Manifest / Pattern | Ecosystem | Template |
| --- | --- | --- |
| `pyproject.toml` | Python | `templates/python.rb.tmpl` |
| `go.mod` | Go | `templates/go.rb.tmpl` |
| `package.json` | Node.js | `templates/node.rb.tmpl` |
| `Cargo.toml` | Rust | Custom (`depends_on "rust" => :build`, `system "cargo", "install", *std_cargo_args`) |
| Standalone executable script | Shell | `templates/shell.rb.tmpl` |

2. Extract metadata from the manifest, `LICENSE`, and git remote:
   - Formula name (lowercase, hyphen-separated, matching the package or CLI name)
   - Binary name (from `project.scripts`, `package.json` `bin`, Go `cmd/` target, Cargo `[[bin]]`, or script filename)
   - License as a valid SPDX identifier (for example, `MIT`, `Apache-2.0`, `GPL-3.0-only`)
   - Homepage URL (GitHub repository URL or manifest homepage)
   - Concise description
3. Fetch release metadata and SHA256 checksum deterministically:
   ```bash
   <skill-dir>/scripts/fetch_release_info.sh
   ```
   Pass `--repo <owner>/<repo>` if CWD is not linked to the target GitHub remote, or `--tag <tag>` if the user requested a specific release.
   - If the script exits with code `2` (no GitHub release exists), stop immediately and ask the user whether they want to create a GitHub release first. Do not create a tag or release without confirmation.
   - If `cwd_dirty` is `true`, inform the user that local uncommitted changes will not be included in the published GitHub release tarball.

### 3. Formula Generation or Update

1. Convert the formula name to a Homebrew Ruby class name:
   - Split on `-` and `_`, capitalize each segment, and join (for example, `my-cli-tool` becomes `MyCliTool`, `foo_bar` becomes `FooBar`).
   - Convert `@` version suffixes to `AT` (for example, `tool@2` becomes `ToolAT2`).
2. Enforce `brew audit --strict` rules on all metadata:
   - `desc`: strictly under 80 characters, no trailing period, and must not start with the formula name or articles (`A`, `An`, `The`).
   - `homepage`: valid `https://` URL.
   - `url` and `sha256`: exact values from `fetch_release_info.sh`.
   - `license`: valid SPDX identifier.
   - Stanza order: `desc`, `homepage`, `url`, `sha256`, `license`, `depends_on`, `resource` blocks (if any), `def install`, `test do`.
3. Render `Formula/<name>.rb` in `/tmp/tap-brewer-work/<tap-repo-name>/` from the matching template:
   - For Python packages with third-party PyPI dependencies, note that `poet <package>` can generate `resource` blocks; add them above `def install` if required.
   - For Go packages whose `main` package is under a subdirectory (for example, `./cmd/<bin>`), set `{{BUILD_PATH}}` accordingly; use `.` when `main.go` is at the repository root.
   - For Node packages, verify `package.json` exposes `bin` entries so `libexec.glob("bin/*")` links the expected executables.
   - Ensure `test do` runs a real command supported by the binary (for example, `--version`, `version`, or `--help`) and asserts expected output.
   - When updating an existing formula, preserve custom `resource` blocks, caveats, or patches unless they are obsolete.

### 4. Tap Repository Refactoring, Re-Documentation, and Validation

1. Derive the Homebrew tap shorthand `<user>/<tap>` by stripping the `homebrew-` prefix from the tap repo name (for example, `alice/homebrew-tap` becomes `alice/tap`).
2. Update the tap's `README.md` formula table deterministically:
   ```bash
   python3 <skill-dir>/scripts/refactor_tap_readme.py \
     --readme /tmp/tap-brewer-work/<tap-repo-name>/README.md \
     --formula <name> \
     --description "<desc>" \
     --tap <user>/<tap> \
     --source https://github.com/<owner>/<repo>
   ```
3. Re-document the tap repository with the `well-document` skill after the formula and table are updated:
   - If the `well-document` skill is installed in the agent environment, load it and run `well-document polish README.md` (and `well-document audit`) against `/tmp/tap-brewer-work/<tap-repo-name>` so directory trees, formula counts, install examples, and cross-links stay grounded and pass the 6-gate anti-slop scorecard.
   - Only update existing tap documentation files; do not scaffold unrequested governance files into the tap repo without explicit user confirmation.
   - If `well-document` is not installed, keep the `refactor_tap_readme.py` output and manually verify that the tap `README.md` has no stale formula lists, broken relative links, or em-dashes.
4. If `brew` is installed locally, validate the formula and fix any reported offenses:
   ```bash
   brew style /tmp/tap-brewer-work/<tap-repo-name>/Formula/<name>.rb
   ```
   If the tap is also tapped locally or the user wants a full audit, run `brew audit --new <user>/<tap>/<name>` for new formulas or `brew audit --strict <user>/<tap>/<name>` for updates.

### 5. Review, Commit, and Push

1. Present a clear review summary to the user:
   - `git -C /tmp/tap-brewer-work/<tap-repo-name> diff --stat` (and `git status --short` if `Formula/<name>.rb` is untracked)
   - Full contents of `Formula/<name>.rb`
   - `git -C /tmp/tap-brewer-work/<tap-repo-name> diff README.md` (plus any other updated tap documentation files)
2. Ask the user to confirm:
   - Whether the changes look right to commit.
   - Whether to push directly to `main` or open a pull request with `gh pr create`.
3. After explicit confirmation, stage `Formula/<name>.rb`, `README.md`, and any other updated tap documentation files, then commit using Conventional Commits:
   - New formula: `feat(formula): add <name> <version>`
   - Updated formula: `chore(formula): bump <name> to <version>`
4. Push according to the user's choice:
   - Direct push: `git push origin main`
   - Pull request: create branch `formula/<name>-<version>`, push it, and run `gh pr create --fill`
5. Output the final verification command:
   ```bash
   brew update && brew install <user>/<tap>/<name>
   ```
