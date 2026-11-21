# tap-brewer

An open-source AI agent skill that publishes the project in your current working directory to a personal Homebrew tap repository (`homebrew-*`), updates the tap `README.md` table, and validates the generated formula.

## Table of Contents

- [Workflow Overview](#workflow-overview)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [Supported Ecosystems](#supported-ecosystems)
- [Repository Layout](#repository-layout)
- [Local Verification](#local-verification)
- [License](#license)

## Workflow Overview

```mermaid
flowchart TD
    A["Preflight: gh auth & tap discovery"] --> B["Clone or pull tap into /tmp/tap-brewer-work"]
    B --> C["Analyze CWD manifest & fetch GitHub release SHA256"]
    C --> D{"GitHub release exists?"}
    D -->|"No (exit 2)"| E["Stop and ask user to create release"]
    D -->|"Yes"| F["Render Formula/<name>.rb from template"]
    F --> G["Update tap README.md table & run brew style"]
    G --> H["Show diff & await confirmation"]
    H --> I["Commit (Conventional Commits) & push or open PR"]
```

## Prerequisites

| Tool | Required | Purpose |
| --- | --- | --- |
| `gh` | Yes | Tap discovery, cloning, release lookup, and PR creation |
| `git` | Yes | Managing the isolated tap working copy |
| `curl` | Yes | Downloading GitHub release tag tarballs |
| `shasum` or `sha256sum` | Yes | Computing deterministic SHA256 checksums |
| `python3` (3.9+) | Yes | Running `scripts/refactor_tap_readme.py` with stdlib only |
| `brew` | Optional | Running local `brew style` and `brew audit` checks |

Authenticate `gh` before using the skill:

```bash
gh auth login
```

## Installation

Clone this repository into your agent's global skills directory.

### Google Antigravity / Gemini CLI

```bash
git clone https://github.com/AtaCanYmc/tap-brewer.git ~/.gemini/config/skills/tap-brewer
```

### Claude Code

```bash
git clone https://github.com/AtaCanYmc/tap-brewer.git ~/.claude/skills/tap-brewer
```

### Codex

```bash
git clone https://github.com/AtaCanYmc/tap-brewer.git ~/.codex/skills/tap-brewer
```

### Cursor

```bash
git clone https://github.com/AtaCanYmc/tap-brewer.git ~/.cursor/skills/tap-brewer
```

## Usage

Run your AI coding agent inside any GitHub-hosted project directory that has at least one published release:

```text
Publish this project to my Homebrew tap using tap-brewer.
```

Specify a tap or release tag explicitly when needed:

```text
Use tap-brewer to update my formula in AtaCanYmc/homebrew-tap for tag v1.4.0 and open a PR.
```

You can also invoke the helper scripts directly:

```bash
# Fetch latest release tag, archive URL, and SHA256 as JSON
./scripts/fetch_release_info.sh --repo owner/project

# Insert or update a formula row in a tap README.md
python3 ./scripts/refactor_tap_readme.py \
  --readme /path/to/homebrew-tap/README.md \
  --formula my-cli \
  --description "Inspect local build caches from the terminal" \
  --tap owner/tap \
  --source https://github.com/owner/my-cli
```

## Supported Ecosystems

| Ecosystem | Detection File | Formula Strategy | Template |
| --- | --- | --- | --- |
| Python | `pyproject.toml` | `Language::Python::Virtualenv` and `virtualenv_install_with_resources` | [`templates/python.rb.tmpl`](templates/python.rb.tmpl) |
| Go | `go.mod` | `go build` with `std_go_args(ldflags: "-s -w")` | [`templates/go.rb.tmpl`](templates/go.rb.tmpl) |
| Node.js | `package.json` | `npm install` with `std_npm_args` and `bin.install_symlink` | [`templates/node.rb.tmpl`](templates/node.rb.tmpl) |
| Shell | Standalone script | Direct `bin.install` mapping | [`templates/shell.rb.tmpl`](templates/shell.rb.tmpl) |
| Rust | `Cargo.toml` | `cargo install` with `std_cargo_args` | Inline in [`SKILL.md`](SKILL.md) |

## Repository Layout

```text
tap-brewer/
├── SKILL.md                        # Agent skill definition and 5-step workflow
├── README.md                       # Setup, usage, and architecture documentation
├── LICENSE                         # MIT license
├── .gitignore                      # Git ignore rules
├── scripts/
│   ├── fetch_release_info.sh       # Deterministic release tag and SHA256 fetcher
│   └── refactor_tap_readme.py      # Zero-dependency tap README.md table updater
├── templates/
│   ├── go.rb.tmpl                  # Go formula template
│   ├── node.rb.tmpl                # Node.js formula template
│   ├── python.rb.tmpl              # Python virtualenv formula template
│   └── shell.rb.tmpl               # Standalone shell script formula template
└── tests/
    └── test_tap_brewer.py          # Stdlib unittest suite for scripts and templates
```

## Local Verification

Run the test suite with Python 3:

```bash
python3 -m unittest discover -s tests -v
```

## License

MIT. See [LICENSE](LICENSE).
