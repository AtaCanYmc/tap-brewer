[← Back to Docs Index](README.md)

# Helper Scripts Reference

Both helper scripts are zero-dependency, executable, and designed for deterministic agent and CLI execution.

## Table of Contents

- [scripts/fetch_release_info.sh](#scriptsfetch_release_infosh)
- [scripts/refactor_tap_readme.py](#scriptsrefactor_tap_readmepy)

## `scripts/fetch_release_info.sh`

Fetches the latest or specified GitHub release tag, downloads the canonical GitHub tag archive tarball, computes its SHA256 digest, and prints JSON to stdout.

### Arguments

| Flag / Argument | Required | Description |
| --- | --- | --- |
| `--repo OWNER/REPO` | No | Target GitHub repository. Defaults to the current directory repository via `gh repo view`. |
| `--tag TAG` | No | Specific release tag to inspect. Defaults to the latest published non-prerelease tag. |
| `-h`, `--help` | No | Print usage summary to stderr and exit `1`. |

### Exit Codes

| Code | Meaning |
| --- | --- |
| `0` | Success. JSON payload written to stdout. |
| `1` | Missing dependency (`gh`, `curl`, `shasum`/`sha256sum`), unauthenticated `gh`, invalid arguments, or download error. |
| `2` | No published GitHub releases found for the repository or specified tag. |

### JSON Output Schema

```json
{
  "repo": "owner/project",
  "tag": "v1.2.3",
  "version": "1.2.3",
  "tarball_url": "https://github.com/owner/project/archive/refs/tags/v1.2.3.tar.gz",
  "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "cwd_dirty": false
}
```

When invoked from a git working tree with uncommitted changes and no `--repo` flag, `cwd_dirty` is set to `true` and a warning is emitted to stderr.

## `scripts/refactor_tap_readme.py`

Parses a Homebrew tap `README.md`, locates the `| Formula | Description | Install | Source |` table, upserts the target formula row, and sorts all rows alphabetically by formula name while preserving surrounding Markdown verbatim.

### Arguments

| Flag | Required | Default | Description |
| --- | --- | --- | --- |
| `--readme PATH` | Yes | None | Path to the tap `README.md`. Created if missing. |
| `--formula NAME` | Yes | None | Formula name without `.rb` extension. |
| `--description TEXT` | Yes | None | Formula description. Pipe characters are escaped automatically. |
| `--tap USER/TAP` | Yes | None | Homebrew tap shorthand without the `homebrew-` prefix. |
| `--source URL` | Yes | None | Source repository URL. GitHub URLs render as `[owner/repo](url)`. |
| `--section HEADING` | No | `Formulas` | Heading name used when appending a new table section. |
| `--dry-run` | No | `false` | Print resulting Markdown to stdout without modifying disk. |

### Example

```bash
python3 ./scripts/refactor_tap_readme.py \
  --readme /tmp/tap-brewer-work/homebrew-tap/README.md \
  --formula my-cli \
  --description "Inspect local build caches" \
  --tap alice/tap \
  --source https://github.com/alice/my-cli \
  --dry-run
```
